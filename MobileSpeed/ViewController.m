//
//  ViewController.m
//  MobileSpeed
//
//  Created by 邹程 on 2020/4/22.
//  Copyright © 2020 邹程. All rights reserved.
//

#import "ViewController.h"
#import "SpeedTestViewController.h"
#import "Marco.h"
#import "Tools.h"
#import "SpeedUpUtils.h"
#import "SpeedUpModels.h"
#import <FCUUID/FCUUID.h>

@interface ViewController ()

@property (copy, nonatomic) NSString *intranetIP;
@property (strong, nonatomic) SpeedUpUtils *speedUpUtils;
@property (strong, nonatomic) SpeedUpAreaInfoModel *areaInfoModel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self getDeviceInfo];

    [self initSpeedUpUtils];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_speedUpUtils getAreaInfo:^(SpeedUpAreaInfoModel *_Nullable model) {
        NSLog(@"%@", model);
        self->_areaInfoModel = model;
        self->_extranetIPLabel.text = [NSString stringWithFormat:@"外网IP：%@", model.ip];
        self->_locationLabel.text = [NSString stringWithFormat:@"当前位置：%@",  model.regionName];
    }];
}

- (void)getDeviceInfo {
    GBDeviceInfo *deviceInfo = [GBDeviceInfo deviceInfo];
    self.osVerLabel.text = [NSString stringWithFormat:@"iOS版本：%lu.%lu.%lu", (unsigned long)deviceInfo.osVersion.major, (unsigned long)deviceInfo.osVersion.minor, (unsigned long)deviceInfo.osVersion.patch];
    self.phoneModelLabel.text = [NSString stringWithFormat:@"手机型号：%@（%@）", deviceInfo.modelString, deviceInfo.rawSystemInfoString];
    self.mobileNetworkStandardLabel.text = [NSString stringWithFormat:@"移动网络：%@%@", [DeviceUtils getDeviceCarrierName], [DeviceUtils getDeviceNetworkName]];
    self.imeiLabel.text = [NSString stringWithFormat:@"UUID：%@", [FCUUID uuid]];
//    self.imsiLabel.text = [DeviceUtils getDeviceIMSIValue];

    PhoneNetManager *phoneNetManager = [PhoneNetManager shareInstance];
//    [phoneNetManager registPhoneNetSDK];

//    NSDictionary *ipDic = [self deviceWANIPAddress];
//    if (ipDic && ipDic.count > 0) {
//        self.extranetIPLabel.text = [NSString stringWithFormat:@"外网IP：%@", ipDic[@"ip"]];
//        self.locationLabel.text = [NSString stringWithFormat:@"当前位置：%@%@",  ipDic[@"country"], ipDic[@"city"]];
//    }

    if ([phoneNetManager.netGetNetworkInfo.deviceNetInfo.netType isEqual:@"WIFI"]) {
        self.intranetIP = phoneNetManager.netGetNetworkInfo.deviceNetInfo.wifiIPV4;
        self.intranetIPLabel.text = [NSString stringWithFormat:@"内网IP：%@", phoneNetManager.netGetNetworkInfo.deviceNetInfo.wifiIPV4];
    } else {
        self.intranetIP = phoneNetManager.netGetNetworkInfo.deviceNetInfo.cellIPV4;
        self.intranetIPLabel.text = [NSString stringWithFormat:@"内网IP：%@", phoneNetManager.netGetNetworkInfo.deviceNetInfo.cellIPV4];
    }

    self.latitudeLabel.text = nil;
    self.longitudeLabel.text = nil;
}

- (NSDictionary *)deviceWANIPAddress {
    NSURL *ipURL = [NSURL URLWithString:@"https://www.ip.cn/"];
    NSData *data = [NSData dataWithContentsOfURL:ipURL];
    NSDictionary *ipDic = nil;
    if (data && data.length > 0) {
        ipDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    }

    return ipDic;
}

- (void)initSpeedUpUtils {
    _speedUpUtils = [[SpeedUpUtils alloc] init];
    if ([[Tools loadStringFromUserDefaults:SP_KEY_CORRELATION_ID] isEqualToString:@"1"]) {
        [self.speedUpButton setTitle:@"停止加速" forState:UIControlStateNormal];
    }
}

- (IBAction)gotoTestAction:(id)sender {
    SpeedTestViewController *speedTestVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"SpeedTest"];
    speedTestVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:speedTestVC animated:YES completion:^{
    }];
}

- (IBAction)speedUpAction:(id)sender {
    if (_areaInfoModel) {
        if ([[Tools loadStringFromUserDefaults:SP_KEY_CORRELATION_ID] isEqualToString:@"1"]) {
            // 取消加速
            [_speedUpUtils cancelTecentGamesQoS:_areaInfoModel.ip cancelTecentGamesQoS:^(SpeedUpCancelTecentGamesQoSModel *_Nullable model) {
                NSLog(@"%@", model);
                if ([model.ResultCode integerValue] == 200) {
                    [self.speedUpButton setTitle:@"一键加速" forState:UIControlStateNormal];
                    [Tools saveToUserDefaults:SP_KEY_CORRELATION_ID value:@"0"];
                }

                if (model.ResultMessage) {
                    [Tools showPrompt:model.ResultMessage superView:self.view numberOfLines:0 afterDelay:3.0 completion:nil];
                }
            }];
        } else {
            if ([_areaInfoModel.ispId integerValue] <= 0) {
                [Tools showPrompt:@"网络运营商不支持4G加速" superView:self.view numberOfLines:1 afterDelay:3.0 completion:nil];
            } else if (([_areaInfoModel.ispId isEqualToString:@"1"] && [_areaInfoModel.areaId isEqualToString:@"440000"]) || [_areaInfoModel.ispId isEqualToString:@"2"]) {
                // 是否需要获取Token
                if ([_areaInfoModel.ispId isEqualToString:@"2"]) {
                    [_speedUpUtils getToken:getTokenUrl];
                } else {
                    [_speedUpUtils getToken:getCmGuandongTokenUrl];
                }
            } else {
                // 直接调用加速
                [_speedUpUtils applyTecentGamesQoS:self.intranetIP publicIp:_areaInfoModel.ip applyTecentGamesQoS:^(SpeedUpApplyTecentGamesQoSModel *_Nullable model) {
                    NSLog(@"%@", model);
                    if ([model.ResultCode integerValue] == 200) {
                        [self.speedUpButton setTitle:@"停止加速" forState:UIControlStateNormal];
                        [Tools saveToUserDefaults:SP_KEY_CORRELATION_ID value:@"1"];
                    }

                    if (model.ResultMessage) {
                        [Tools showPrompt:model.ResultMessage superView:self.view numberOfLines:0 afterDelay:3.0 completion:nil];
                    }
                }];
            }
        }
    } else {
        [Tools showPrompt:@"无法获取区域信息" superView:self.view numberOfLines:1 afterDelay:3.0 completion:nil];
    }
}

@end