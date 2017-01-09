//
//  RNNetworkInfo.m
//  RNNetworkInfo
//
//  Created by Corey Wilson on 7/12/15.
//  Copyright (c) 2015 eastcodes. All rights reserved.
//

#import "RNNetworkInfo.h"

#import <ifaddrs.h>
#import <arpa/inet.h>
#include <stdio.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <string.h>

#if TARGET_IPHONE_SIMULATOR
#include <net/route.h>
#else
#include "route.h"
#endif

#define CTL_NET 4               /* network, see socket.h */
#define ROUNDUP(a) \
((a) > 0 ? (1 + (((a) - 1) | (sizeof(long) - 1))) : sizeof(long))

@import SystemConfiguration.CaptiveNetwork;

/*
http://stackoverflow.com/questions/35677731/how-to-get-router-ip-address-in-swift-or-objective-c
*/
static int getdefaultgateway(in_addr_t * addr)
{
    int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET,
        NET_RT_FLAGS, RTF_GATEWAY};
    size_t l;
    char * buf, * p;
    struct rt_msghdr * rt;
    struct sockaddr * sa;
    struct sockaddr * sa_tab[RTAX_MAX];
    int i;
    int r = -1;
    if(sysctl(mib, sizeof(mib)/sizeof(int), 0, &l, 0, 0) < 0) {
        return -1;
    }
    if(l>0) {
        buf = malloc(l);
        if(sysctl(mib, sizeof(mib)/sizeof(int), buf, &l, 0, 0) < 0) {
            return -1;
        }
        for(p=buf; p<buf+l; p+=rt->rtm_msglen) {
            rt = (struct rt_msghdr *)p;
            sa = (struct sockaddr *)(rt + 1);
            for(i=0; i<RTAX_MAX; i++) {
                if(rt->rtm_addrs & (1 << i)) {
                    sa_tab[i] = sa;
                    sa = (struct sockaddr *)((char *)sa + ROUNDUP(sa->sa_len));
                } else {
                    sa_tab[i] = NULL;
                }
            }

            if( ((rt->rtm_addrs & (RTA_DST|RTA_GATEWAY)) == (RTA_DST|RTA_GATEWAY))
               && sa_tab[RTAX_DST]->sa_family == AF_INET
               && sa_tab[RTAX_GATEWAY]->sa_family == AF_INET) {


                if(((struct sockaddr_in *)sa_tab[RTAX_DST])->sin_addr.s_addr == 0) {
                    char ifName[128];
                    if_indextoname(rt->rtm_index,ifName);

                    if(strcmp("en0",ifName)==0){

                        *addr = ((struct sockaddr_in *)(sa_tab[RTAX_GATEWAY]))->sin_addr.s_addr;
                        r = 0;
                    }
                }
            }
        }
        free(buf);
    }
    return r;
}

@implementation RNNetworkInfo

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(getSSID:(RCTResponseSenderBlock)callback)
{
    NSArray *interfaceNames = CFBridgingRelease(CNCopySupportedInterfaces());
    NSLog(@"%s: Supported interfaces: %@", __func__, interfaceNames);

    NSDictionary *SSIDInfo;
    NSString *SSID = @"error";

    for (NSString *interfaceName in interfaceNames) {
        SSIDInfo = CFBridgingRelease(CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName));

        if (SSIDInfo.count > 0) {
            SSID = SSIDInfo[@"SSID"];
            break;
        }
    }

    callback(@[SSID]);
}

RCT_EXPORT_METHOD(getIPAddress:(RCTResponseSenderBlock)callback)
{
    NSString *address = @"error";

    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;

    success = getifaddrs(&interfaces);

    if (success == 0) {
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }

    freeifaddrs(interfaces);
    callback(@[address]);
}

RCT_EXPORT_METHOD(getRouterIPAddress:(RCTResponseSenderBlock)callback)
{
    struct in_addr gatewayaddr;
    int r = getdefaultgateway(&(gatewayaddr.s_addr));
    NSString routerIPAddress = @"error";
    if (r >= 0) {
        routerIPAddress = [NSString stringWithFormat: @"%s",inet_ntoa(gatewayaddr)];
    }
    callback(@[routerIPAddress]);
}

@end
