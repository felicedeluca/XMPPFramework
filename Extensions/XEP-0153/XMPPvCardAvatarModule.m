//
//  XMPPvCardAvatarModule.h
//  XEP-0153 vCard-Based Avatars
//
//  Created by Eric Chamberlain on 3/9/11.
//  Copyright 2011 RF.com. All rights reserved.


// TODO: publish after upload vCard
/*
 * XEP-0153 Section 4.2 rule 1
 *
 * However, a client MUST advertise an image if it has just uploaded the vCard with a new avatar 
 * image. In this case, the client MAY choose not to redownload the vCard to verify its contents.
 */

#import "XMPPvCardAvatarModule.h"

#import "NSDataAdditions.h"
#import "NSXMLElementAdditions.h"
#import "XMPPLogging.h"
#import "XMPPPresence.h"
#import "XMPPStream.h"
#import "XMPPvCardTempModule.h"


// Log levels: off, error, warn, info, verbose
// Log flags: trace
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;


NSString *const kXMPPvCardAvatarElement = @"x";
NSString *const kXMPPvCardAvatarNS = @"vcard-temp:x:update";
NSString *const kXMPPvCardAvatarPhotoElement = @"photo";


@implementation XMPPvCardAvatarModule

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init/dealloc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)init
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPvCardAvatarModule.h are supported.
	
	return [self initWithvCardTempModule:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPvCardAvatarModule.h are supported.
	
	return [self initWithvCardTempModule:nil dispatchQueue:NULL];
}

- (id)initWithvCardTempModule:(XMPPvCardTempModule *)xmppvCardTempModule
{
  return [self initWithvCardTempModule:xmppvCardTempModule dispatchQueue:NULL];
}

- (id)initWithvCardTempModule:(XMPPvCardTempModule *)xmppvCardTempModule dispatchQueue:(dispatch_queue_t)queue
{
  NSParameterAssert(xmppvCardTempModule != nil);
  
	if ((self = [super initWithDispatchQueue:queue])) {
    _xmppvCardTempModule = [xmppvCardTempModule retain];
    _moduleStorage = [(id <XMPPvCardAvatarStorage>)xmppvCardTempModule.moduleStorage retain];
    
    [_xmppvCardTempModule addDelegate:self delegateQueue:queue];
	}
	return self;
}


- (void)dealloc {
  [_xmppvCardTempModule removeDelegate:self];
  
  [_moduleStorage release];
  _moduleStorage = nil;
  
  [_xmppvCardTempModule release];
  _xmppvCardTempModule = nil;
  
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSData *)photoDataForJID:(XMPPJID *)jid {
  NSData *photoData = [_moduleStorage photoDataForJID:jid];
  
  if (photoData == nil) {
    [_xmppvCardTempModule fetchvCardTempForJID:jid useCache:YES];
  }
  return photoData;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStreamDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamWillConnect:(XMPPStream *)sender {
  /* 
   * XEP-0153 Section 4.2 rule 1
   *
   * A client MUST NOT advertise an avatar image without first downloading the current vCard. 
   * Once it has done this, it MAY advertise an image. 
   */
  [_moduleStorage clearvCardTempForJID:[sender myJID]];
}


- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
  [_xmppvCardTempModule fetchvCardTempForJID:[sender myJID] useCache:NO];
}


- (void)xmppStream:(XMPPStream *)sender willSendPresence:(XMPPPresence *)presence {  
  // add our photo info to the presence stanza
  NSXMLElement *photoElement = nil;
  NSXMLElement *xElement = [NSXMLElement elementWithName:kXMPPvCardAvatarElement xmlns:kXMPPvCardAvatarNS];
  
  NSString *photoHash = [_moduleStorage photoHashForJID:[sender myJID]];
  
   if (photoHash != nil) {
     photoElement = [NSXMLElement elementWithName:kXMPPvCardAvatarPhotoElement stringValue:photoHash];
   } else {
     photoElement = [NSXMLElement elementWithName:kXMPPvCardAvatarPhotoElement];
   }
   
   [xElement addChild:photoElement];
   [presence addChild:xElement];
}


- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence  {
  NSXMLElement *xElement = [presence elementForName:kXMPPvCardAvatarElement xmlns:kXMPPvCardAvatarNS];
  
  if (xElement == nil) {
    return;
  }
  
  NSString *photoHash = [[xElement elementForName:kXMPPvCardAvatarPhotoElement] stringValue];
  
  if (photoHash == nil || [photoHash isEqualToString:@""]) {
    return;
  }
  
  XMPPJID *jid = [presence from];
  
  // check the hash
  if (![photoHash isEqualToString:[_moduleStorage photoHashForJID:jid]]) {
    [_xmppvCardTempModule fetchvCardTempForJID:jid useCache:NO];
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPvCardTempModuleDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule 
        didReceivevCardTemp:(XMPPvCardTemp *)vCardTemp 
                     forJID:(XMPPJID *)jid
                 xmppStream:(XMPPStream *)aXmppStream {
  /*
   * XEP-0153 4.1.3
   * If the client subsequently obtains an avatar image (e.g., by updating or retrieving the vCard), 
   * it SHOULD then publish a new <presence/> stanza with character data in the <photo/> element.
   */
  if ([jid isEqual:[[aXmppStream myJID] bareJID]]) {
    NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
    
    [aXmppStream sendElement:presence];
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Getter/setter
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize xmppvCardTempModule = _xmppvCardTempModule;


@end