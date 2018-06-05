//
//  MultipeerConnectivity.m
//  ARKit
//
//  Created by Mac on 2018/6/5.
//  Copyright © 2018年 AR. All rights reserved.
//

#import "MultipeerConnectivity.h"

@interface MultipeerConnectivity ()<MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate>

@end

@implementation MultipeerConnectivity

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        NSString *serviceType = @"ar-multi-sample";
        
        self.myPeerID = [[MCPeerID alloc] initWithDisplayName:[UIDevice currentDevice].name];
        
        self.session = [[MCSession alloc] initWithPeer:self.myPeerID securityIdentity:nil encryptionPreference:MCEncryptionRequired];
        self.session.delegate = self;
        
        self.serviceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.myPeerID discoveryInfo:nil serviceType:serviceType];
        self.serviceAdvertiser.delegate = self;
        [self.serviceAdvertiser startAdvertisingPeer];
        
        self.serviceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.myPeerID serviceType:serviceType];
        self.serviceBrowser.delegate = self;
        [self.serviceBrowser startBrowsingForPeers];
    }
    
    return self;
}

- (void)sendToAllPeers:(NSData *)data
{
    @try {
        [self.session sendData:data toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
    } @catch (NSException *exception) {
        NSLog(@"error sending data to peers: \(error.localizedDescription)");
    } @finally {
        
    }
}

- (NSArray<MCPeerID *> *)connectedPeers
{
    return self.session.connectedPeers;
}

#pragma mark MCSessionDelegate
// Remote peer changed state.
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    
}

// Received data from remote peer.
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(receivedDataHandler:PeerID:)]) {
        [self.delegate receivedDataHandler:data PeerID:peerID];
    }
}

// Received a byte stream from remote peer.
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    assert(@"This service does not send/receive streams.");
}

// Start receiving a resource from remote peer.
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    assert(@"This service does not send/receive resources.");
}

// Finished receiving a resource from remote peer and saved the content
// in a temporary location - the app is responsible for moving the file
// to a permanent location within its sandbox.
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(nullable NSURL *)localURL withError:(nullable NSError *)error
{
    assert(@"This service does not send/receive resources.");
}

#pragma mark MCNearbyServiceBrowserDelegate
// Found a nearby advertising peer.
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info
{
    // Invite the new peer to the session.
    [browser invitePeer:peerID toSession:self.session withContext:nil timeout:10];
}

// A nearby peer has stopped advertising.
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    // This app doesn't do anything with non-invited peers, so there's nothing to do here.
}

#pragma mark MCNearbyServiceAdvertiserDelegate
// Incoming invitation request.  Call the invitationHandler block with YES
// and a valid session to connect the inviting peer to the session.
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(nullable NSData *)context invitationHandler:(void (^)(BOOL accept, MCSession * __nullable session))invitationHandler
{
    // Call handler to accept invitation and join the session.
    invitationHandler(true, self.session);
}

@end
