//
//  PanoramaController.m
//  VRPanoramaKit
//
//  Created by 小发工作室 on 2017/9/21.
//  Copyright © 2017年 小发工作室. All rights reserved.
//

#import "PanoramaController.h"
#import "PanoramaUtil.h"

#define ES_PI  (3.14159265f)
#define MAX_VIEW_DEGREE 110.0f  //最大视角
#define MIN_VIEW_DEGREE 50.0f   //最小视角
#define FRAME_PER_SENCOND 60.0  //帧数

@interface PanoramaController ()<GLKViewControllerDelegate,GLKViewDelegate>

// 相机的广角角度
@property (nonatomic, assign) CGFloat        overture;

// 索引数
@property (nonatomic, assign) GLsizei        numIndices;

// 顶点索引缓存指针
@property (nonatomic, assign) GLuint         vertexIndicesBuffer;

// 顶点缓存指针
@property (nonatomic, assign) GLuint         vertexBuffer;

// 纹理缓存指针
@property (nonatomic, assign) GLuint         vertexTexCoord;

// 着色器
@property (nonatomic, strong) GLKBaseEffect  *effect;

// 图片的纹理信息
@property (nonatomic, strong) GLKTextureInfo *textureInfo;

// 模型坐标系
@property (nonatomic, assign) GLKMatrix4     modelViewMatrix;

// 手势平移距离
@property (nonatomic, assign) CGFloat        panX;
@property (nonatomic, assign) CGFloat        panY;

//两指缩放大小
@property (nonatomic, assign) CGFloat        scale;

//是否双击
@property (nonatomic, assign) BOOL           isTapScale;

//是否根据陀螺仪旋转
@property (nonatomic, assign) BOOL           isMotion;

//测试按钮
@property (nonatomic, strong) UIButton       *startButton;
@property (nonatomic, strong) UIButton       *endButton;

@end

@implementation PanoramaController


- (CMMotionManager *)motionManager {
    if (_motionManager == nil) {
        
        _motionManager = [[CMMotionManager alloc] init];
        
        _motionManager.deviceMotionUpdateInterval = 1/FRAME_PER_SENCOND;
        _motionManager.showsDeviceMovementDisplay = YES;

    }
    return _motionManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self createPanoramView];
    }
    return self;
}

- (instancetype)initWithImageName:(NSString *)imageName type:(NSString *)type{
    self = [super init];
    if (self) {
        self.imageName     = imageName;
        self.imageNameType = type;
        
        if (type.length == 0) {
            
            type = @"jpg";
        }
        [self createPanoramView];
     }
    return self;
}

- (void)startPanoramViewMotion{
    self.isMotion = YES;

    self.delegate                         = self;
    self.preferredFramesPerSecond         = FRAME_PER_SENCOND;

    [self setupOpenGL];

    
    [self startDeviceMotion];
}

- (void)stopPanoramViewMotion {
    self.isMotion = NO;
}

#pragma -Private

- (void)createPanoramView {
    if (self.imageName == nil) {
        NSAssert(self.imageName.length != 0, @"image name is nil,please check image name of PanoramView");
        return;
    }
    
    EAGLContext *context                  = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    self.panoramaView                     = (GLKView *)self.view;
    self.panoramaView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    self.panoramaView.drawableDepthFormat = GLKViewDrawableDepthFormat24;

    self.panoramaView.context             = context;
    self.panoramaView.delegate            = self;
    [EAGLContext setCurrentContext:context];
    
    [self addGesture];

    [self startPanoramViewMotion];
}

#pragma mark set device Motion
- (void)startDeviceMotion {
    [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical];
    _modelViewMatrix = GLKMatrix4Identity;
}

- (void)stopDeviceMotion {
    [self.motionManager stopDeviceMotionUpdates];
    [self.motionManager stopAccelerometerUpdates];
}

#pragma mark setup OpenGL

- (void)setupOpenGL {
    glEnable(GL_DEPTH_TEST);
    
    // 顶点
    GLfloat *vVertices  = NULL;

    // 纹理
    GLfloat *vTextCoord = NULL;

    // 索引
    GLuint *indices     = NULL;

    int numVertices     = 0;

    _numIndices         = esGenSphere(200, 1.0, &vVertices, &vTextCoord, &indices, &numVertices);
    
    
    // 创建索引buffer并将indices的数据放入
    glGenBuffers(1, &_vertexIndicesBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _vertexIndicesBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, _numIndices*sizeof(GLuint), indices, GL_STATIC_DRAW);
    
    // 创建顶点buffer并将vVertices中的数据放入
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, numVertices*3*sizeof(GLfloat), vVertices, GL_STATIC_DRAW);
    
    //设置顶点属性,对顶点的位置，颜色，坐标进行赋值
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*3, NULL);
    
    // 创建纹理buffer并将vTextCoord数据放入
    glGenBuffers(1, &_vertexTexCoord);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexTexCoord);
    glBufferData(GL_ARRAY_BUFFER, numVertices*2*sizeof(GLfloat), vTextCoord, GL_DYNAMIC_DRAW);
    
    //设置纹理属性,对纹理的位置，颜色，坐标进行赋值
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat)*2, NULL);
    
    NSString *filePath = [[NSBundle mainBundle]pathForResource:self.imageName ofType:self.imageNameType];
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:@(1),GLKTextureLoaderOriginBottomLeft, nil];
    
    GLKTextureInfo *textureInfo = [GLKTextureLoader textureWithContentsOfFile:filePath
                                                                      options:options
                                                                        error:nil];
    
    _effect                    = [[GLKBaseEffect alloc]init];
    _effect.texture2d0.enabled = GL_TRUE;
    _effect.texture2d0.name    = textureInfo.name;
}

#pragma mark Gesture

- (void)addGesture {
    /// 平移手势
    UIPanGestureRecognizer *pan =[[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(panGestture:)];
    
    /// 捏合手势
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(pinchGesture:)];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(tapGesture:)];
    
    tap.numberOfTouchesRequired = 1;
    tap.numberOfTapsRequired    = 2;
    
    [self.view addGestureRecognizer:pinch];
    [self.view addGestureRecognizer:pan];
    [self.view addGestureRecognizer:tap];

    _scale = 1.0;
    
}

- (void)panGestture:(UIPanGestureRecognizer *)sender {
    
    CGPoint point = [sender translationInView:self.view];
    _panX         += point.x;
    _panY         += point.y;
    
    //转换之后归零
    [sender setTranslation:CGPointZero inView:self.view];
}

- (void)pinchGesture:(UIPinchGestureRecognizer *)sender {
    _scale       *= sender.scale;
    sender.scale = 1.0;
}

- (void)tapGesture:(UITapGestureRecognizer *)sender {
    if (!_isTapScale) {
        
        _isTapScale = YES;
        
        _scale = 1.5;
    }
    else
    {
        _scale = 1.0;
        _isTapScale = NO;
    }
}

#pragma mark -GLKViewDelegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    /**清除颜色缓冲区内容时候: 使用白色填充*/
    glClearColor(1.0f, 1.0f, 1.0f, 0.0f);
    /**清除颜色缓冲区与深度缓冲区内容*/
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    [_effect prepareToDraw];
//    glDrawElements(GL_TRIANGLES, _numIndices, GL_UNSIGNED_SHORT, 0);
    glDrawElements(GL_TRIANGLES, _numIndices, GL_UNSIGNED_INT,0);

}

#pragma mark GLKViewControllerDelegate

- (void)glkViewControllerUpdate:(GLKViewController *)controller {
    CGSize size    = self.view.bounds.size;
    float aspect   = fabs(size.width / size.height);
    /*
     *在全景效果中，捏合手势用于放大缩小。
     *我们可以通过UIPinchGestureRecognizer可以拿到捏合手势的scale, 根据scale可以调整透视投影的视角大小，
     *在透视投影中，通过调整视角大小（fov: Field of *View），可以达到放大缩小的效果，视角越大，物体越小。（视角大小就是GLKMatrix4MakePerspective函数的第一个参数）
     */
    CGFloat radius = [self rotateFromFocalLengh];
    
    /**GLKMatrix4MakePerspective 配置透视图
     第一个参数, 类似于相机的焦距, 比如10表示窄角度, 100表示广角 一般65-75;
     第二个参数: 表示时屏幕的纵横比
     第三个, 第四参数: 是为了实现透视效果, 近大远处小, 要确保模型位于远近平面之间
     */
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(radius), aspect, 0.1f, 10);
    projectionMatrix = GLKMatrix4Scale(projectionMatrix, -1.0f, 1.0f, 1.0f);

    _effect.transform.projectionMatrix = projectionMatrix;
    
    // 陀螺仪旋转角度（四元数形式）
    CMDeviceMotion *deviceMotion = self.motionManager.deviceMotion;
    double w = deviceMotion.attitude.quaternion.w;
    double x = deviceMotion.attitude.quaternion.x;
    double y = deviceMotion.attitude.quaternion.y;
    double z = deviceMotion.attitude.quaternion.z;
    GLKQuaternion quaternion = GLKQuaternionMake(-x,  y, z, w);
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    // 手指上下滑动，绕X轴旋转
    modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, -0.005 * _panY);
    // 手指左右滑动, 绕Y轴旋转
    modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, 0.005 * _panX);
    // 陀螺仪（手机自身旋转）
    modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, GLKMatrix4MakeWithQuaternion(quaternion));
    // 为了保证在水平放置手机的时候, 是从上往下看, 因此首先坐标系沿着x轴旋转90度
    modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, M_PI_2);
    
//    // 如果加上这个z轴的平移，就会把物体沿着z轴负方向移动2，也就相当于摄像机或者眼睛的位置后移了，这样就看到一个球体外壁了，就像看地球仪，而不是从球心看内壁
//    modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, GLKMatrix4MakeTranslation(0, 0, -2));
    // 设置模型视图矩阵
    _effect.transform.modelviewMatrix = modelViewMatrix;
    //https://daniate.com/2020/01/30/183.html（一篇关于GLKit矩阵的文章）
}

- (void)glkViewController:(GLKViewController *)controller willPause:(BOOL)pause{
    NSLog(@"pause:%d", pause);
}

- (CGFloat)rotateFromFocalLengh{
    CGFloat radius = 100 / _scale;
    
    // radius不小于50, 不大于110;
    if (radius < MIN_VIEW_DEGREE) {
        
        radius = MIN_VIEW_DEGREE;
        _scale = 1 / (MIN_VIEW_DEGREE / 100);
        
    }
    if (radius > MAX_VIEW_DEGREE) {
        
        radius = MAX_VIEW_DEGREE;
        _scale = 1 / (MAX_VIEW_DEGREE / 100);
    }
    
    return radius;
}

@end
