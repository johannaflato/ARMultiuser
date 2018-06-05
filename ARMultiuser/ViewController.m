//
//  ViewController.m
//  ARKit
//
//  Created by szt on 2017/6/7.
//  Copyright © 2017年 AR. All rights reserved.
//

#import "ViewController.h"
#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>
#import "PlaneNode.h"
#import "Player.h"
#import "FocusSquare.h"
#import "ResManager.h"
#import "MultipeerConnectivity.h"

@interface ViewController ()<ARSCNViewDelegate, ARSessionDelegate, SCNPhysicsContactDelegate, MultipeerConnectivityDelegate>
{
    CGPoint screenCenter;
    NSMutableArray *walks;
    NSMutableArray *idles;
    
    NSMutableArray *playerArr;
    
    ARAnchor    *recodeAnchor;
}

@property(nonatomic, strong)ARSCNView *sceneView;

@property(nonatomic, strong)ARWorldTrackingConfiguration *configuration;

@property (strong, atomic, readwrite)PlaneNode* planeNode;

@property(nonatomic, strong)FocusSquare *focusSquare;

@property(nonatomic, strong)MultipeerConnectivity *multipeerSession;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.multipeerSession = [[MultipeerConnectivity alloc] init];
    self.multipeerSession.delegate = self;
    
    [self setupSceneView];
    
    [self loadRes];
    
    [self setupFocusSquare];
    
    [self setupGestureRecognizer];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0.0, 0.0, 100, 50.0);
    btn.backgroundColor = [UIColor redColor];
    [btn addTarget:self action:@selector(click) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
}

- (void)click
{
    [self.sceneView.session getCurrentWorldMapWithCompletionHandler:^(ARWorldMap * _Nullable worldMap, NSError * _Nullable error) {
        if (error) {
            NSLog(@"error====%@",error);
        }
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:worldMap requiringSecureCoding:true error:nil];
        [self.multipeerSession sendToAllPeers:data];
    }];
}

#pragma mark MultipeerConnectivityDelegate
- (void)receivedDataHandler:(NSData *)data PeerID:(MCPeerID *)peerID
{
    id unarchived = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARWorldMap classForKeyedUnarchiver] fromData:data error:nil];
    
    if ([unarchived isKindOfClass:[ARWorldMap class]]) {
        NSLog(@"[unarchived class]====%@",[unarchived class]);
        ARWorldMap *worldMap = unarchived;
        self.configuration = [[ARWorldTrackingConfiguration alloc] init];
        self.configuration.worldAlignment = ARWorldAlignmentGravity;
        self.configuration.planeDetection = ARPlaneDetectionHorizontal|ARPlaneDetectionVertical;
        self.configuration.initialWorldMap = worldMap;
        [self.sceneView.session runWithConfiguration:self.configuration options:ARSessionRunOptionResetTracking|ARSessionRunOptionRemoveExistingAnchors];
        
        return;
    }
    
    unarchived = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARAnchor classForKeyedUnarchiver] fromData:data error:nil];
    
    if ([unarchived isKindOfClass:[ARAnchor class]]) {
        NSLog(@"[unarchived class]====%@",[unarchived class]);
        ARAnchor *anchor = unarchived;
        
        [self.sceneView.session addAnchor:anchor];
        
        return;
    }
    
    NSLog(@"unknown data recieved from \(%@)",peerID.displayName);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self setupSession];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self pauseSession];
}

- (void)setupSceneView
{
    self.sceneView = [[ARSCNView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self.view addSubview:self.sceneView];
    self.sceneView.session.delegate = self;
    self.sceneView.delegate = self;
    self.sceneView.contentScaleFactor = 1.3;
    
    SCNScene *scene = [[SCNScene alloc] init];
    self.sceneView.scene = scene;
    self.sceneView.scene.physicsWorld.contactDelegate = self;
    
    screenCenter = CGPointMake(CGRectGetMidX(self.sceneView.bounds), CGRectGetMidY(self.sceneView.bounds));
    
    // add environment lights
    [self enableEnvironmentMapWithIntensity:25.0];
}

- (void)enableEnvironmentMapWithIntensity:(CGFloat)intensity
{
    self.sceneView.autoenablesDefaultLighting = NO;
    self.sceneView.automaticallyUpdatesLighting = NO;
    
    if (!self.sceneView.scene.lightingEnvironment.contents) {
        self.sceneView.scene.lightingEnvironment.contents = [UIImage imageNamed:@"spherical.jpg"];
    }
    
    self.sceneView.scene.lightingEnvironment.intensity = intensity;
}

- (void)setupSession
{
    self.configuration = [[ARWorldTrackingConfiguration alloc] init];
    self.configuration.worldAlignment = ARWorldAlignmentGravity;
    self.configuration.planeDetection = ARPlaneDetectionHorizontal|ARPlaneDetectionVertical;
    self.configuration.lightEstimationEnabled = YES;
    [self.sceneView.session runWithConfiguration:self.configuration];
    self.sceneView.session.delegate = self;
    self.sceneView.debugOptions = ARSCNDebugOptionShowFeaturePoints;
//    [ARSCNDebugOptions.showFeaturePoints]
}

- (void)pauseSession
{
    [self.sceneView.session pause];
}

- (void)setupGestureRecognizer
{
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    NSMutableArray *gestureRecognizers = [NSMutableArray array];
    [gestureRecognizers addObject:tapGesture];
    [gestureRecognizers addObjectsFromArray:self.sceneView.gestureRecognizers];
    self.sceneView.gestureRecognizers = gestureRecognizers;
}

- (void)loadRes
{
    walks = [ResManager loadActionResource:@"Kakashi(walking).dae"];
    idles = [ResManager loadActionResource:@"Kakashi(idle).dae"];
}

- (void)setupPlayerWithPos:(SCNVector3 )position
{
    if (!playerArr) {
        playerArr = [NSMutableArray array];
    }
    
    Player *player = [[Player alloc] initWithModelScene:[SCNScene sceneNamed:@"Kakashi.dae"]];
    player.characterNode.scale = SCNVector3Make(0.001, 0.001, 0.001);
    player.characterNode.position = position;
    
    [player addAnimates:walks forKey:@"walking"];
    [player addAnimates:idles forKey:@"idle"];
    
    [self.sceneView.scene.rootNode addChildNode:player.characterNode];
    
    [playerArr addObject:player];
    
    int rotate = [self getRandomNumber:-180 to:180];
    player.characterNode.rotation = SCNVector4Make(0.0, 1.0, 0.0, rotate);
    
    int x = arc4random() % 3;
    
    if (x == 0) {
        [player playAnimatesForkey:@"walking"];
    }else{
        [player playAnimatesForkey:@"idle"];
    }
}

- (int)getRandomNumber:(int)from to:(int)to
{
    return (int)(from + (arc4random() % (to - from + 1)));
}

- (void)setupFocusSquare
{
    if (self.focusSquare) {
        [self.focusSquare removeFromParentNode];
        self.focusSquare = nil;
    }
    
    self.focusSquare = [[FocusSquare alloc] init];
    [self.sceneView.scene.rootNode addChildNode:self.focusSquare];
}

- (void)updateFocusSquare
{
    SCNVector3 existPos = [self worldPositionFromScreenPosition:screenCenter types:ARHitTestResultTypeExistingPlaneUsingGeometry];
    SCNVector3 virtualPos = [self worldPositionFromScreenPosition:screenCenter types:ARHitTestResultTypeExistingPlane];
    
    if (existPos.x == 0 && existPos.y == 0 && existPos.z == 0) {
        [self.focusSquare update:virtualPos];
        [self.focusSquare hide];
    }else{
        [self.focusSquare update:existPos];
        [self.focusSquare unhide];
    }
}

- (void)updatePlayers
{
    for (Player * player in playerArr) {
        SCNVector3 dir = [self getDirection];
        player.characterNode.position = SCNVector3Make(player.characterNode.position.x + dir.x * 0.001, player.characterNode.position.y, player.characterNode.position.z +dir.z * 0.001);
    }
}

- (SCNVector3)worldPositionFromScreenPosition:(CGPoint)position types:(ARHitTestResultType)types
{
    ARHitTestResult *result = [self.sceneView hitTest:position types:types].firstObject;
    
    recodeAnchor = [[ARAnchor alloc] initWithName:@"kakaxi" transform:result.worldTransform];
    SCNVector3 planeHitTestPosition = [self positionFromTransform:result.worldTransform];
    
    return planeHitTestPosition;
}

- (ARPlaneAnchor *)getPlaneAnchor:(CGPoint)position
{
    ARHitTestResult *result = [self.sceneView hitTest:position types:ARHitTestResultTypeExistingPlaneUsingExtent].firstObject;
    
    if (!result) {
        return nil;
    }
    
    ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)result.anchor;
    
    return planeAnchor;
}

- (SCNVector3)positionFromTransform:(matrix_float4x4)transform
{
    return SCNVector3Make(transform.columns[3].x, transform.columns[3].y, transform.columns[3].z);
}

#pragma mark - ARSCNViewDelegate
// Override to create and configure nodes for anchors added to the view's session.
- (SCNNode *)renderer:(id<SCNSceneRenderer>)renderer nodeForAnchor:(ARAnchor *)anchor
{
    if (![anchor isKindOfClass:[ARPlaneAnchor class]]) {
        return nil;
    }

    PlaneNode *planeNode = [[PlaneNode alloc] init];
    [planeNode updateShapeNodeWithAnchor:(ARPlaneAnchor*)anchor];

    return planeNode;
}

- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time
{
    [self updateFocusSquare];
    
//    [self updatePlayers];
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor
{
    if ([node isKindOfClass:[PlaneNode class]] && [anchor isKindOfClass:[ARPlaneAnchor class]]) {
        [(PlaneNode*)node updateShapeNodeWithAnchor:(ARPlaneAnchor*)anchor];
    }
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didRemoveNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor
{
    if ([node isKindOfClass:[PlaneNode class]] && [anchor isKindOfClass:[ARPlaneAnchor class]]) {
        [(PlaneNode*)node removeFromParentNode];
    }
}

#pragma mark - ARSessionDelegate
- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame
{
    
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<ARAnchor*>*)anchors
{
    for (ARAnchor *anchor in anchors) {
        if ([anchor.name isEqualToString:@"kakaxi"]) {
            SCNVector3 planeHitTestPosition = [self positionFromTransform:anchor.transform];
            [self setupPlayerWithPos:planeHitTestPosition];
        }
    }
}

- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<ARAnchor*>*)anchors
{
//    NSLog(@"更新平面");
}

- (void)session:(ARSession *)session didRemoveAnchors:(NSArray<ARAnchor*>*)anchors
{
//    NSLog(@"移除平面");
}

#pragma mark - SCNPhysicsContactDelegate
- (void)physicsWorld:(SCNPhysicsWorld *)world didBeginContact:(SCNPhysicsContact *)contact
{
    NSString *nodeNameA = contact.nodeA.name;
    NSString *nodeNameB = contact.nodeB.name;
    
    SCNNode *node;
    if ([nodeNameA isEqualToString:@"ball"] && [nodeNameB isEqualToString:@"box"]) {
        node = contact.nodeB;
        [self removeNodeWithAnimation:node];
    } else if ([nodeNameA isEqualToString:@"box"] && [nodeNameB isEqualToString:@"ball"]){
        node = contact.nodeA;
        [self removeNodeWithAnimation:node];
    }
}

- (void)removeNodeWithAnimation:(SCNNode *)node
{
    SCNParticleSystem *particle = [SCNParticleSystem particleSystemNamed:@"explosion" inDirectory:nil];
    SCNNode *particleNode = [SCNNode node];
    [particleNode addParticleSystem:particle];
    particleNode.position = node.position;
    [self.sceneView.scene.rootNode addChildNode:particleNode];
    
    [node removeFromParentNode];
}

- (void)handleTap:(UIGestureRecognizer*)gestureRecognize
{
    if ([self.focusSquare isInPlane]) {
        [self.sceneView.session addAnchor:recodeAnchor];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:recodeAnchor requiringSecureCoding:true error:nil];
        [self.multipeerSession sendToAllPeers:data];
    }
}

- (SCNVector3)getDirection
{
    ARFrame *frame = self.sceneView.session.currentFrame;
    
    if (frame) {
        // camera's rotation and translation in world coordinates
        SCNMatrix4 mat = SCNMatrix4FromMat4(frame.camera.transform);
        // orientation of camera in world space
        SCNVector3 dir = SCNVector3Make(mat.m31, mat.m32, mat.m33);
        
        return dir;
    }
    
    return SCNVector3Make(0.0, 0.0, -1.0);
}
@end
