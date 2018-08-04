//
//  TestSignalOperationMethodTests.m
//  TestSignalOperationMethodTests
//
//  Created by ys on 2018/8/2.
//  Copyright © 2018年 ys. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <ReactiveCocoa.h>

@interface TestSignalOperationMethodTests : XCTestCase

@end

@implementation TestSignalOperationMethodTests

- (RACSignal *)syncSignal
{
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        for (int i = 0; i < 5; i++) {
            NSLog(@"signal -- %d", i);
            [subscriber sendNext:@(i)];
        }
        [subscriber sendCompleted];
        
        return nil;
    }];
}

- (RACSignal *)asyncSignal
{
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        for (int i = 0; i < 5; i++) {
            NSLog(@"signal -- %d", i);
            [subscriber sendNext:@(i)];
        }
        [[RACScheduler mainThreadScheduler] afterDelay:3 schedule:^{
            NSLog(@"signal -- completed");
            [subscriber sendCompleted];
        }];
        
        return nil;
    }];
}

- (RACSignal *)asyncSignal1
{
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        NSLog(@"start");
        [[RACScheduler mainThreadScheduler] afterDelay:3 schedule:^{
            NSLog(@"end");
            [subscriber sendCompleted];
        }];
        
        return nil;
    }];
}

- (RACSignal *)errorSignal1
{
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        NSLog(@"error -- le");
        [subscriber sendNext:@"errorSignal"];
        [subscriber sendError:nil];
        
        return nil;
    }];
}

- (void)testThrottle1
{
    [[[self syncSignal]
      throttle:2]
     subscribeNext:^(id x) {
         NSLog(@"throttle -- %@", x);
     }];
    
    // 打印日志
    /*
    2018-08-03 20:05:59.581505+0800 TestSignalOperationMethod[55538:5507224] signal -- 0
    2018-08-03 20:05:59.581913+0800 TestSignalOperationMethod[55538:5507224] signal -- 1
    2018-08-03 20:05:59.582096+0800 TestSignalOperationMethod[55538:5507224] signal -- 2
    2018-08-03 20:05:59.582253+0800 TestSignalOperationMethod[55538:5507224] signal -- 3
    2018-08-03 20:05:59.582388+0800 TestSignalOperationMethod[55538:5507224] signal -- 4
    2018-08-03 20:05:59.582552+0800 TestSignalOperationMethod[55538:5507224] throttle -- 4
     */
    // 由于是同步信号，在2s内所有值的都发送，直接获取最后一个值，并完成了信号的订阅。
}

- (void)testThrottle2
{
    [[[self asyncSignal]
      throttle:2]
     subscribeNext:^(id x) {
         NSLog(@"throttle -- %@", x);
     }];
    
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-03 20:09:34.757395+0800 TestSignalOperationMethod[55705:5518916] signal -- 0
     2018-08-03 20:09:34.757770+0800 TestSignalOperationMethod[55705:5518916] signal -- 1
     2018-08-03 20:09:34.757957+0800 TestSignalOperationMethod[55705:5518916] signal -- 2
     2018-08-03 20:09:34.758157+0800 TestSignalOperationMethod[55705:5518916] signal -- 3
     2018-08-03 20:09:34.758360+0800 TestSignalOperationMethod[55705:5518916] signal -- 4
     2018-08-03 20:09:36.765698+0800 TestSignalOperationMethod[55705:5518916] throttle -- 4
     2018-08-03 20:09:37.765821+0800 TestSignalOperationMethod[55705:5518916] signal -- completed
     */
    // 这时由于asyncSignal中最后一个值是延时3s发送的，所以不会舍去掉4，而且可以注意到throttle -- 4是在2s后发送的。
}

- (void)testThrottleValuesPassingTest
{
    [[[self syncSignal]
      throttle:2 valuesPassingTest:^BOOL(NSNumber *next) {
          int x = [next intValue];
          return x == 2;
      }]
     subscribeNext:^(id x) {
         NSLog(@"throttle -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 20:13:23.158891+0800 TestSignalOperationMethod[55862:5530465] signal -- 0
     2018-08-03 20:13:23.159222+0800 TestSignalOperationMethod[55862:5530465] throttle -- 0
     2018-08-03 20:13:23.159382+0800 TestSignalOperationMethod[55862:5530465] signal -- 1
     2018-08-03 20:13:23.159497+0800 TestSignalOperationMethod[55862:5530465] throttle -- 1
     2018-08-03 20:13:23.159600+0800 TestSignalOperationMethod[55862:5530465] signal -- 2
     2018-08-03 20:13:23.159839+0800 TestSignalOperationMethod[55862:5530465] signal -- 3
     2018-08-03 20:13:23.160216+0800 TestSignalOperationMethod[55862:5530465] throttle -- 3
     2018-08-03 20:13:23.160488+0800 TestSignalOperationMethod[55862:5530465] signal -- 4
     2018-08-03 20:13:23.160840+0800 TestSignalOperationMethod[55862:5530465] throttle -- 4
     */
}

- (void)testDelay
{
    [[[self syncSignal]
      delay:1]
     subscribeNext:^(id x) {
         NSLog(@"delay -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-03 20:17:20.601273+0800 TestSignalOperationMethod[56041:5543080] signal -- 0
     2018-08-03 20:17:20.602095+0800 TestSignalOperationMethod[56041:5543080] signal -- 1
     2018-08-03 20:17:20.603993+0800 TestSignalOperationMethod[56041:5543080] signal -- 2
     2018-08-03 20:17:20.604686+0800 TestSignalOperationMethod[56041:5543080] signal -- 3
     2018-08-03 20:17:20.604956+0800 TestSignalOperationMethod[56041:5543080] signal -- 4
     2018-08-03 20:17:21.602146+0800 TestSignalOperationMethod[56041:5543080] delay -- 0
     2018-08-03 20:17:21.616815+0800 TestSignalOperationMethod[56041:5543080] delay -- 1
     2018-08-03 20:17:21.617169+0800 TestSignalOperationMethod[56041:5543080] delay -- 2
     2018-08-03 20:17:21.617429+0800 TestSignalOperationMethod[56041:5543080] delay -- 3
     2018-08-03 20:17:21.617751+0800 TestSignalOperationMethod[56041:5543080] delay -- 4
     */
}

- (void)testRepeat1
{
    [[[self syncSignal]
      repeat]
     subscribeNext:^(id x) {
         NSLog(@"repeat -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 20:19:07.809200+0800 TestSignalOperationMethod[56119:5548613] signal -- 0
     2018-08-03 20:19:07.809893+0800 TestSignalOperationMethod[56119:5548613] repeat -- 0
     2018-08-03 20:19:07.810218+0800 TestSignalOperationMethod[56119:5548613] signal -- 1
     2018-08-03 20:19:07.810568+0800 TestSignalOperationMethod[56119:5548613] repeat -- 1
     2018-08-03 20:19:07.810989+0800 TestSignalOperationMethod[56119:5548613] signal -- 2
     2018-08-03 20:19:07.811301+0800 TestSignalOperationMethod[56119:5548613] repeat -- 2
     2018-08-03 20:19:07.811413+0800 TestSignalOperationMethod[56119:5548613] signal -- 3
     2018-08-03 20:19:07.811720+0800 TestSignalOperationMethod[56119:5548613] repeat -- 3
     2018-08-03 20:19:07.813233+0800 TestSignalOperationMethod[56119:5548613] signal -- 4
     2018-08-03 20:19:07.813398+0800 TestSignalOperationMethod[56119:5548613] repeat -- 4
     */
    // 运行此测试方法，会发现一直重复执行下去的
}

- (void)testRepeat2
{
    [[[self asyncSignal1]
      repeat]
     subscribeNext:^(id x) {
//         NSLog(@"repeat -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-03 21:52:59.264955+0800 TestSignalOperationMethod[58852:5745168] start
     2018-08-03 21:53:02.270168+0800 TestSignalOperationMethod[58852:5745168] end
     2018-08-03 21:53:02.270841+0800 TestSignalOperationMethod[58852:5745168] start
     2018-08-03 21:53:05.288020+0800 TestSignalOperationMethod[58852:5745168] end
     2018-08-03 21:53:05.288333+0800 TestSignalOperationMethod[58852:5745168] start
     2018-08-03 21:53:08.304397+0800 TestSignalOperationMethod[58852:5745168] end
     2018-08-03 21:53:08.304673+0800 TestSignalOperationMethod[58852:5745168] start
     */
    // 可以看出就算信号是异步的最终的订阅也是串行订阅。其实这也就是repeat的含义，重复进行。
}

- (void)testCatch
{
    RACSignal * (^catchBlock)(NSError *error) = ^(NSError *error) {
        NSLog(@"catchBlock");
        return  [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
            NSLog(@"catchSignal");
            [subscriber sendNext:@"catchSignal"];
            return nil;
        }];
    };
    
    [[[self errorSignal1] catch:catchBlock]
     subscribeNext:^(id x) {
         NSLog(@"catch -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 21:17:06.955496+0800 TestSignalOperationMethod[58384:5719333] error -- le
     2018-08-03 21:17:06.955709+0800 TestSignalOperationMethod[58384:5719333] catch -- errorSignal
     2018-08-03 21:17:06.956085+0800 TestSignalOperationMethod[58384:5719333] catchBlock
     2018-08-03 21:17:06.956304+0800 TestSignalOperationMethod[58384:5719333] catchSignal
     2018-08-03 21:17:06.956694+0800 TestSignalOperationMethod[58384:5719333] catch -- catchSignal
     */
    // 可以看出当源信号发生错误的时候，会接着对catchBlock()获得的signal进行订阅。通过catch这个名字也可以知道，发生异常的时候做些额外的处理。
}

- (void)testCatchTo
{
    RACSignal *catchSignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSLog(@"catchSignal");
        [subscriber sendNext:@"catchSignal"];
        return nil;
    }];
    
    [[[self errorSignal1] catchTo:catchSignal]
     subscribeNext:^(id x) {
         NSLog(@"catchTo -- %@", x);
     }];

    // 打印日志
    /*
     2018-08-03 22:01:42.203679+0800 TestSignalOperationMethod[59278:5772017] error -- le
     2018-08-03 22:01:42.204269+0800 TestSignalOperationMethod[59278:5772017] catchTo -- errorSignal
     2018-08-03 22:01:42.204474+0800 TestSignalOperationMethod[59278:5772017] catchSignal
     2018-08-03 22:01:42.204616+0800 TestSignalOperationMethod[59278:5772017] catchTo -- catchSignal

     */
}

- (void)testTry
{
    [[[self syncSignal]
      try:^BOOL(NSNumber *value, NSError *__autoreleasing *errorPtr) {
          if ([value intValue] == 0) {
              return YES;
          }
          return NO;
      }]
     subscribeNext:^(id x) {
         NSLog(@"try -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 22:07:15.916801+0800 TestSignalOperationMethod[59569:5789739] signal -- 0
     2018-08-03 22:07:15.917049+0800 TestSignalOperationMethod[59569:5789739] try -- 0
     2018-08-03 22:07:15.917245+0800 TestSignalOperationMethod[59569:5789739] signal -- 1
     2018-08-03 22:07:15.917440+0800 TestSignalOperationMethod[59569:5789739] signal -- 2
     2018-08-03 22:07:15.917551+0800 TestSignalOperationMethod[59569:5789739] signal -- 3
     2018-08-03 22:07:15.917642+0800 TestSignalOperationMethod[59569:5789739] signal -- 4
     */

}

- (void)testTryMap
{
    [[[self syncSignal]
      tryMap:^id(NSNumber *value, NSError *__autoreleasing *errorPtr) {
          if ([value intValue] == 0) {
              return @(100);
          }
          return nil;
      }]
     subscribeNext:^(id x) {
         NSLog(@"tryMap -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 22:11:18.662277+0800 TestSignalOperationMethod[59760:5802015] signal -- 0
     2018-08-03 22:11:18.662933+0800 TestSignalOperationMethod[59760:5802015] tryMap -- 100
     2018-08-03 22:11:18.664925+0800 TestSignalOperationMethod[59760:5802015] signal -- 1
     2018-08-03 22:11:18.665181+0800 TestSignalOperationMethod[59760:5802015] signal -- 2
     2018-08-03 22:11:18.665465+0800 TestSignalOperationMethod[59760:5802015] signal -- 3
     2018-08-03 22:11:18.665730+0800 TestSignalOperationMethod[59760:5802015] signal -- 4
     */
}

- (void)testInitially
{
    [[[self syncSignal]
      initially:^{
          NSLog(@"开始");
      }]
     subscribeNext:^(id x) {
         NSLog(@"initially -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 22:35:57.234228+0800 TestSignalOperationMethod[60863:5873234] 开始
     2018-08-03 22:35:57.234945+0800 TestSignalOperationMethod[60863:5873234] signal -- 0
     2018-08-03 22:35:57.235129+0800 TestSignalOperationMethod[60863:5873234] initially -- 0
     2018-08-03 22:35:57.235236+0800 TestSignalOperationMethod[60863:5873234] signal -- 1
     2018-08-03 22:35:57.235382+0800 TestSignalOperationMethod[60863:5873234] initially -- 1
     2018-08-03 22:35:57.235656+0800 TestSignalOperationMethod[60863:5873234] signal -- 2
     2018-08-03 22:35:57.235792+0800 TestSignalOperationMethod[60863:5873234] initially -- 2
     2018-08-03 22:35:57.236002+0800 TestSignalOperationMethod[60863:5873234] signal -- 3
     2018-08-03 22:35:57.236111+0800 TestSignalOperationMethod[60863:5873234] initially -- 3
     2018-08-03 22:35:57.236202+0800 TestSignalOperationMethod[60863:5873234] signal -- 4
     2018-08-03 22:35:57.236510+0800 TestSignalOperationMethod[60863:5873234] initially -- 4
     */
}

- (void)testDefer
{
    [[RACSignal defer:^RACSignal *{
        return [self syncSignal];
    }]
     subscribeNext:^(id x) {
         NSLog(@"defer -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 23:36:39.003680+0800 TestSignalOperationMethod[63447:6045507] signal -- 0
     2018-08-03 23:36:39.004321+0800 TestSignalOperationMethod[63447:6045507] defer -- 0
     2018-08-03 23:36:39.005382+0800 TestSignalOperationMethod[63447:6045507] signal -- 1
     2018-08-03 23:36:39.006493+0800 TestSignalOperationMethod[63447:6045507] defer -- 1
     2018-08-03 23:36:39.006653+0800 TestSignalOperationMethod[63447:6045507] signal -- 2
     2018-08-03 23:36:39.007226+0800 TestSignalOperationMethod[63447:6045507] defer -- 2
     2018-08-03 23:36:39.007627+0800 TestSignalOperationMethod[63447:6045507] signal -- 3
     2018-08-03 23:36:39.007903+0800 TestSignalOperationMethod[63447:6045507] defer -- 3
     2018-08-03 23:36:39.008112+0800 TestSignalOperationMethod[63447:6045507] signal -- 4
     2018-08-03 23:36:39.008401+0800 TestSignalOperationMethod[63447:6045507] defer -- 4
     */
}

- (void)testFinally
{
    [[[self syncSignal]
      finally:^{
          NSLog(@"finally");
      }]
     subscribeNext:^(id x) {
         NSLog(@"finally -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 23:38:26.430286+0800 TestSignalOperationMethod[63550:6051389] signal -- 0
     2018-08-03 23:38:26.430502+0800 TestSignalOperationMethod[63550:6051389] finally -- 0
     2018-08-03 23:38:26.430617+0800 TestSignalOperationMethod[63550:6051389] signal -- 1
     2018-08-03 23:38:26.430721+0800 TestSignalOperationMethod[63550:6051389] finally -- 1
     2018-08-03 23:38:26.430818+0800 TestSignalOperationMethod[63550:6051389] signal -- 2
     2018-08-03 23:38:26.430918+0800 TestSignalOperationMethod[63550:6051389] finally -- 2
     2018-08-03 23:38:26.431003+0800 TestSignalOperationMethod[63550:6051389] signal -- 3
     2018-08-03 23:38:26.431113+0800 TestSignalOperationMethod[63550:6051389] finally -- 3
     2018-08-03 23:38:26.431230+0800 TestSignalOperationMethod[63550:6051389] signal -- 4
     2018-08-03 23:38:26.431434+0800 TestSignalOperationMethod[63550:6051389] finally -- 4
     2018-08-03 23:38:26.431656+0800 TestSignalOperationMethod[63550:6051389] finally
     */
}

- (void)testBuffer
{
    [[[self asyncSignal]
      bufferWithTime:5 onScheduler:[RACScheduler mainThreadScheduler]]
     subscribeNext:^(id x) {
         NSLog(@"buffer -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-03 23:41:24.213438+0800 TestSignalOperationMethod[63720:6060889] signal -- 0
     2018-08-03 23:41:24.213888+0800 TestSignalOperationMethod[63720:6060889] signal -- 1
     2018-08-03 23:41:24.214032+0800 TestSignalOperationMethod[63720:6060889] signal -- 2
     2018-08-03 23:41:24.214126+0800 TestSignalOperationMethod[63720:6060889] signal -- 3
     2018-08-03 23:41:24.214213+0800 TestSignalOperationMethod[63720:6060889] signal -- 4
     2018-08-03 23:41:27.217767+0800 TestSignalOperationMethod[63720:6060889] signal -- completed
     2018-08-03 23:41:27.218674+0800 TestSignalOperationMethod[63720:6060889] buffer -- <RACTuple: 0x60400000bdf0> (
     0,
     1,
     2,
     3,
     4
     )

     */
}

- (void)testCollect
{
    [[[self syncSignal]
      collect]
     subscribeNext:^(id x) {
         NSLog(@"collect -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 23:43:11.282920+0800 TestSignalOperationMethod[63814:6066715] signal -- 0
     2018-08-03 23:43:11.283196+0800 TestSignalOperationMethod[63814:6066715] signal -- 1
     2018-08-03 23:43:11.283924+0800 TestSignalOperationMethod[63814:6066715] signal -- 2
     2018-08-03 23:43:11.285014+0800 TestSignalOperationMethod[63814:6066715] signal -- 3
     2018-08-03 23:43:11.285450+0800 TestSignalOperationMethod[63814:6066715] signal -- 4
     2018-08-03 23:43:11.286422+0800 TestSignalOperationMethod[63814:6066715] collect -- (
     0,
     1,
     2,
     3,
     4
     )
     */
}

- (void)testAggregateWithStartFactory
{
    [[[self syncSignal]
      aggregateWithStartFactory:^id{
          return @(100);
      } reduce:^id(NSNumber *running, NSNumber *next) {
          return @([running intValue] + [next intValue]);
      }]
     subscribeNext:^(id x) {
         NSLog(@"aggregateWithStartFactory -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 23:46:37.553243+0800 TestSignalOperationMethod[63994:6077317] signal -- 0
     2018-08-03 23:46:37.553449+0800 TestSignalOperationMethod[63994:6077317] signal -- 1
     2018-08-03 23:46:37.553682+0800 TestSignalOperationMethod[63994:6077317] signal -- 2
     2018-08-03 23:46:37.554173+0800 TestSignalOperationMethod[63994:6077317] signal -- 3
     2018-08-03 23:46:37.554602+0800 TestSignalOperationMethod[63994:6077317] signal -- 4
     2018-08-03 23:46:37.555017+0800 TestSignalOperationMethod[63994:6077317] aggregateWithStartFactory -- 110
     */
}

- (void)testAggregateWithStart
{
    [[[self syncSignal]
      aggregateWithStart:@(100) reduce:^id(NSNumber *running, NSNumber *next) {
          return @([running intValue] + [next intValue]);
      }]
     subscribeNext:^(id x) {
         NSLog(@"aggregateWithStart -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 23:51:05.449457+0800 TestSignalOperationMethod[64200:6090970] signal -- 0
     2018-08-03 23:51:05.449743+0800 TestSignalOperationMethod[64200:6090970] signal -- 1
     2018-08-03 23:51:05.454037+0800 TestSignalOperationMethod[64200:6090970] signal -- 2
     2018-08-03 23:51:05.456090+0800 TestSignalOperationMethod[64200:6090970] signal -- 3
     2018-08-03 23:51:05.458225+0800 TestSignalOperationMethod[64200:6090970] signal -- 4
     2018-08-03 23:51:05.458623+0800 TestSignalOperationMethod[64200:6090970] aggregateWithStart -- 110
     */
}

- (void)testAggregateWithStartIndex
{
    [[[self syncSignal]
      aggregateWithStart:@(100) reduceWithIndex:^id(id running, id next, NSUInteger index) {
          return @([running intValue] + [next intValue] + index);
      }]
     subscribeNext:^(id x) {
         NSLog(@"testAggregateWithStartIndex -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 23:52:27.277486+0800 TestSignalOperationMethod[64273:6095238] signal -- 0
     2018-08-03 23:52:27.277709+0800 TestSignalOperationMethod[64273:6095238] signal -- 1
     2018-08-03 23:52:27.277861+0800 TestSignalOperationMethod[64273:6095238] signal -- 2
     2018-08-03 23:52:27.277983+0800 TestSignalOperationMethod[64273:6095238] signal -- 3
     2018-08-03 23:52:27.278096+0800 TestSignalOperationMethod[64273:6095238] signal -- 4
     2018-08-03 23:52:27.278279+0800 TestSignalOperationMethod[64273:6095238] testAggregateWithStartIndex -- 120
     */
}

- (void)testTakeLast
{
    [[[self syncSignal]
      takeLast:1]
     subscribeNext:^(id x) {
         NSLog(@"takeLast -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-03 23:54:24.033486+0800 TestSignalOperationMethod[64379:6101416] signal -- 0
     2018-08-03 23:54:24.034213+0800 TestSignalOperationMethod[64379:6101416] signal -- 1
     2018-08-03 23:54:24.034319+0800 TestSignalOperationMethod[64379:6101416] signal -- 2
     2018-08-03 23:54:24.034774+0800 TestSignalOperationMethod[64379:6101416] signal -- 3
     2018-08-03 23:54:24.036413+0800 TestSignalOperationMethod[64379:6101416] signal -- 4
     2018-08-03 23:54:24.036859+0800 TestSignalOperationMethod[64379:6101416] takeLast -- 4
     */
}

- (void)testCombineLatestWith
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"x1"];
        [[RACScheduler mainThreadScheduler] afterDelay:1 schedule:^{
            [subscriber sendNext:@"x2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2 schedule:^{
            [subscriber sendNext:@"x3"];
        }];
        
        return nil;
    }];
    
    RACSignal *signal2 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"y1"];
        [[RACScheduler mainThreadScheduler] afterDelay:0.5 schedule:^{
            [subscriber sendNext:@"y2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2.5 schedule:^{
            [subscriber sendNext:@"y3"];
        }];
        
        return nil;
    }];
    
    [[signal1 combineLatestWith:signal2]
     subscribeNext:^(id x) {
         NSLog(@"combineLatestWith -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-03 23:58:27.031587+0800 TestSignalOperationMethod[64587:6114374] combineLatestWith -- <RACTuple: 0x60000001f5b0> (
     x1,
     y1
     )
     2018-08-03 23:58:27.537661+0800 TestSignalOperationMethod[64587:6114374] combineLatestWith -- <RACTuple: 0x604000015a40> (
     x1,
     y2
     )
     2018-08-03 23:58:28.038420+0800 TestSignalOperationMethod[64587:6114374] combineLatestWith -- <RACTuple: 0x604000015a70> (
     x2,
     y2
     )
     2018-08-03 23:58:29.031716+0800 TestSignalOperationMethod[64587:6114374] combineLatestWith -- <RACTuple: 0x604000015a90> (
     x3,
     y2
     )
     2018-08-03 23:58:29.537932+0800 TestSignalOperationMethod[64587:6114374] combineLatestWith -- <RACTuple: 0x604000015ac0> (
     x3,
     y3
     )

     */
}

- (void)testCombineLatest
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"x1"];
        [[RACScheduler mainThreadScheduler] afterDelay:1 schedule:^{
            [subscriber sendNext:@"x2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2 schedule:^{
            [subscriber sendNext:@"x3"];
        }];
        
        return nil;
    }];
    
    RACSignal *signal2 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"y1"];
        [[RACScheduler mainThreadScheduler] afterDelay:0.5 schedule:^{
            [subscriber sendNext:@"y2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2.5 schedule:^{
            [subscriber sendNext:@"y3"];
        }];
        
        return nil;
    }];
    
    [[RACSignal combineLatest:@[signal1, signal2]]
     subscribeNext:^(id x) {
         NSLog(@"combineLatest -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-04 00:01:00.553591+0800 TestSignalOperationMethod[64723:6122629] combineLatest -- <RACTuple: 0x604000012d30> (
     x1,
     y1
     )
     2018-08-04 00:01:01.059108+0800 TestSignalOperationMethod[64723:6122629] combineLatest -- <RACTuple: 0x604000012db0> (
     x1,
     y2
     )
     2018-08-04 00:01:01.565218+0800 TestSignalOperationMethod[64723:6122629] combineLatest -- <RACTuple: 0x600000008e40> (
     x2,
     y2
     )
     2018-08-04 00:01:02.553597+0800 TestSignalOperationMethod[64723:6122629] combineLatest -- <RACTuple: 0x604000012e40> (
     x3,
     y2
     )
     2018-08-04 00:01:03.054799+0800 TestSignalOperationMethod[64723:6122629] combineLatest -- <RACTuple: 0x604000012c60> (
     x3,
     y3
     )

     */

}

- (void)testCombineLatestReduce
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"x1"];
        [[RACScheduler mainThreadScheduler] afterDelay:1 schedule:^{
            [subscriber sendNext:@"x2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2 schedule:^{
            [subscriber sendNext:@"x3"];
        }];
        
        return nil;
    }];
    
    RACSignal *signal2 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"y1"];
        [[RACScheduler mainThreadScheduler] afterDelay:0.5 schedule:^{
            [subscriber sendNext:@"y2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2.5 schedule:^{
            [subscriber sendNext:@"y3"];
        }];
        
        return nil;
    }];
    
    [[RACSignal combineLatest:@[signal1, signal2] reduce:^(NSString *x, NSString *y){
        return [x stringByAppendingString:y];
    }]
     subscribeNext:^(id x) {
         NSLog(@"combineLatestReduce -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-04 00:03:14.337886+0800 TestSignalOperationMethod[64841:6129527] combineLatestReduce -- x1y1
     2018-08-04 00:03:14.841014+0800 TestSignalOperationMethod[64841:6129527] combineLatestReduce -- x1y2
     2018-08-04 00:03:15.346906+0800 TestSignalOperationMethod[64841:6129527] combineLatestReduce -- x2y2
     2018-08-04 00:03:16.354960+0800 TestSignalOperationMethod[64841:6129527] combineLatestReduce -- x3y2
     2018-08-04 00:03:16.851545+0800 TestSignalOperationMethod[64841:6129527] combineLatestReduce -- x3y3
     */
}

- (void)testMerge
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"x1"];
        [[RACScheduler mainThreadScheduler] afterDelay:1 schedule:^{
            [subscriber sendNext:@"x2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2 schedule:^{
            [subscriber sendNext:@"x3"];
        }];
        
        return nil;
    }];
    
    RACSignal *signal2 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"y1"];
        [[RACScheduler mainThreadScheduler] afterDelay:0.5 schedule:^{
            [subscriber sendNext:@"y2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2.5 schedule:^{
            [subscriber sendNext:@"y3"];
        }];
        
        return nil;
    }];
    
    [[signal1 merge:signal2]
     subscribeNext:^(id x) {
         NSLog(@"merge -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-04 00:06:47.843578+0800 TestSignalOperationMethod[65032:6141056] merge -- x1
     2018-08-04 00:06:47.844095+0800 TestSignalOperationMethod[65032:6141056] merge -- y1
     2018-08-04 00:06:48.351929+0800 TestSignalOperationMethod[65032:6141056] merge -- y2
     2018-08-04 00:06:48.844079+0800 TestSignalOperationMethod[65032:6141056] merge -- x2
     2018-08-04 00:06:49.844159+0800 TestSignalOperationMethod[65032:6141056] merge -- x3
     2018-08-04 00:06:50.349136+0800 TestSignalOperationMethod[65032:6141056] merge -- y3
     */
}

- (void)testMerge1
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"x1"];
        [[RACScheduler mainThreadScheduler] afterDelay:1 schedule:^{
            [subscriber sendNext:@"x2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2 schedule:^{
            [subscriber sendNext:@"x3"];
        }];
        
        return nil;
    }];
    
    RACSignal *signal2 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"y1"];
        [[RACScheduler mainThreadScheduler] afterDelay:0.5 schedule:^{
            [subscriber sendNext:@"y2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2.5 schedule:^{
            [subscriber sendNext:@"y3"];
        }];
        
        return nil;
    }];
    
    [[RACSignal merge:@[signal1, signal2]]
     subscribeNext:^(id x) {
         NSLog(@"merge -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-04 00:08:47.709408+0800 TestSignalOperationMethod[65141:6147497] merge -- x1
     2018-08-04 00:08:47.710318+0800 TestSignalOperationMethod[65141:6147497] merge -- y1
     2018-08-04 00:08:48.221167+0800 TestSignalOperationMethod[65141:6147497] merge -- y2
     2018-08-04 00:08:48.719165+0800 TestSignalOperationMethod[65141:6147497] merge -- x2
     2018-08-04 00:08:49.719512+0800 TestSignalOperationMethod[65141:6147497] merge -- x3
     2018-08-04 00:08:50.220585+0800 TestSignalOperationMethod[65141:6147497] merge -- y3

     */
}

- (void)testFlatten
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"x1"];
        [[RACScheduler mainThreadScheduler] afterDelay:1 schedule:^{
            [subscriber sendNext:@"x2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2 schedule:^{
            [subscriber sendNext:@"x3"];
        }];
        
        return nil;
    }];
    RACSignal *signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        for (int i = 0; i < 5; i++) {
            [subscriber sendNext:signal1];
        }
        [subscriber sendCompleted];
        
        return nil;
    }];
    [[signal
      flatten:2]
     subscribeNext:^(id x) {
         NSLog(@"flatten -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-04 00:16:52.155700+0800 TestSignalOperationMethod[65548:6172448] flatten -- x1
     2018-08-04 00:16:52.156651+0800 TestSignalOperationMethod[65548:6172448] flatten -- x1
     2018-08-04 00:16:53.164874+0800 TestSignalOperationMethod[65548:6172448] flatten -- x2
     2018-08-04 00:16:53.165223+0800 TestSignalOperationMethod[65548:6172448] flatten -- x2
     2018-08-04 00:16:54.170599+0800 TestSignalOperationMethod[65548:6172448] flatten -- x3
     2018-08-04 00:16:54.171230+0800 TestSignalOperationMethod[65548:6172448] flatten -- x3
     
     */
}

- (void)testThen
{
    [[[self syncSignal] then:^RACSignal *{
        return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
            [subscriber sendNext:@"then"];
            [subscriber sendCompleted];
            return nil;
        }];
    }]
     subscribeNext:^(id x) {
         NSLog(@"then -- %@", x);
     }];
    
    // 打印日志
    /*
     2018-08-04 00:19:51.139510+0800 TestSignalOperationMethod[65708:6181571] signal -- 0
     2018-08-04 00:19:51.140024+0800 TestSignalOperationMethod[65708:6181571] signal -- 1
     2018-08-04 00:19:51.140219+0800 TestSignalOperationMethod[65708:6181571] signal -- 2
     2018-08-04 00:19:51.140343+0800 TestSignalOperationMethod[65708:6181571] signal -- 3
     2018-08-04 00:19:51.140616+0800 TestSignalOperationMethod[65708:6181571] signal -- 4
     2018-08-04 00:19:51.140891+0800 TestSignalOperationMethod[65708:6181571] then -- then
     */
}

- (void)testIgnoreValues
{
    [[[self syncSignal]
      ignoreValues]
     subscribeNext:^(id x) {
         NSLog(@"ignoreValues -- %@", x);
     } completed:^{
         NSLog(@"ignoreValues - completed");
     }];
    
    // 打印日志
    /*
     2018-08-04 00:21:31.721922+0800 TestSignalOperationMethod[65794:6186934] signal -- 0
     2018-08-04 00:21:31.723196+0800 TestSignalOperationMethod[65794:6186934] signal -- 1
     2018-08-04 00:21:31.723509+0800 TestSignalOperationMethod[65794:6186934] signal -- 2
     2018-08-04 00:21:31.723846+0800 TestSignalOperationMethod[65794:6186934] signal -- 3
     2018-08-04 00:21:31.724335+0800 TestSignalOperationMethod[65794:6186934] signal -- 4
     2018-08-04 00:21:31.724803+0800 TestSignalOperationMethod[65794:6186934] ignoreValues - completed

     */
}

- (void)testConcat
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"x1"];
        [[RACScheduler mainThreadScheduler] afterDelay:1 schedule:^{
            [subscriber sendNext:@"x2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2 schedule:^{
            [subscriber sendNext:@"x3"];
        }];
        
        return nil;
    }];
    RACSignal *signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        for (int i = 0; i < 5; i++) {
            [subscriber sendNext:signal1];
        }
        [subscriber sendCompleted];
        
        return nil;
    }];
    [[signal
      concat]
     subscribeNext:^(id x) {
         NSLog(@"concat -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-04 00:23:06.639054+0800 TestSignalOperationMethod[65885:6192239] concat -- x1
     2018-08-04 00:23:07.645898+0800 TestSignalOperationMethod[65885:6192239] concat -- x2
     2018-08-04 00:23:08.652961+0800 TestSignalOperationMethod[65885:6192239] concat -- x3
     
     */
}

- (void)testSetKeyPath
{
    CALayer *layer = [[CALayer alloc] init];
    
    [[self syncSignal] setKeyPath:@"name" onObject:layer nilValue:@"default"];
    
    NSLog(@"setKeyPath -- %@", [layer valueForKeyPath:@"name"]);
    
    /*
     2018-08-04 00:30:28.742337+0800 TestSignalOperationMethod[66263:6214929] signal -- 0
     2018-08-04 00:30:28.744878+0800 TestSignalOperationMethod[66263:6214929] signal -- 1
     2018-08-04 00:30:28.746911+0800 TestSignalOperationMethod[66263:6214929] signal -- 2
     2018-08-04 00:30:28.747197+0800 TestSignalOperationMethod[66263:6214929] signal -- 3
     2018-08-04 00:30:28.747463+0800 TestSignalOperationMethod[66263:6214929] signal -- 4
     2018-08-04 00:30:28.748813+0800 TestSignalOperationMethod[66263:6214929] setKeyPath -- 4
     */
}

- (void)testInterval
{
    [[RACSignal interval:1 onScheduler:[RACScheduler mainThreadScheduler] withLeeway:1]
     subscribeNext:^(id x) {
         NSLog(@"interval -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];

    /*
     2018-08-04 00:32:56.641699+0800 TestSignalOperationMethod[66412:6223143] interval -- Sat Aug  4 00:32:56 2018
     2018-08-04 00:32:57.649910+0800 TestSignalOperationMethod[66412:6223143] interval -- Sat Aug  4 00:32:57 2018
     2018-08-04 00:32:58.654922+0800 TestSignalOperationMethod[66412:6223143] interval -- Sat Aug  4 00:32:58 2018
     2018-08-04 00:32:59.661688+0800 TestSignalOperationMethod[66412:6223143] interval -- Sat Aug  4 00:32:59 2018
     2018-08-04 00:33:00.653812+0800 TestSignalOperationMethod[66412:6223143] interval -- Sat Aug  4 00:33:00 2018
     2018-08-04 00:33:01.655059+0800 TestSignalOperationMethod[66412:6223143] interval -- Sat Aug  4 00:33:01 2018
     2018-08-04 00:33:02.652974+0800 TestSignalOperationMethod[66412:6223143] interval -- Sat Aug  4 00:33:02 2018
     2018-08-04 00:33:03.652020+0800 TestSignalOperationMethod[66412:6223143] interval -- Sat Aug  4 00:33:03 2018
     2018-08-04 00:33:04.641321+0800 TestSignalOperationMethod[66412:6223143] interval -- Sat Aug  4 00:33:04 2018
     2018-08-04 00:33:05.651244+0800 TestSignalOperationMethod[66412:6223143] interval -- Sat Aug  4 00:33:05 2018

     */
}

- (void)testTakeUntil
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"x1"];
        [[RACScheduler mainThreadScheduler] afterDelay:1 schedule:^{
            [subscriber sendNext:@"x2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2 schedule:^{
            [subscriber sendNext:@"x3"];
        }];
        
        return nil;
    }];
    
    RACSignal *signal2 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [[RACScheduler mainThreadScheduler] afterDelay:0.3 schedule:^{
            [subscriber sendNext:@"y1"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:0.5 schedule:^{
            [subscriber sendNext:@"y2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2.5 schedule:^{
            [subscriber sendNext:@"y3"];
        }];
        
        return nil;
    }];
    
    [[signal1 takeUntil:signal2]
     subscribeNext:^(id x) {
         NSLog(@"takeUntil -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];

    // 打印日志
    /*
     2018-08-04 00:36:01.737214+0800 TestSignalOperationMethod[66583:6233076] takeUntil -- x1
     */
}

- (void)testtakeUntilReplacement
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@"x1"];
        [[RACScheduler mainThreadScheduler] afterDelay:1 schedule:^{
            [subscriber sendNext:@"x2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2 schedule:^{
            [subscriber sendNext:@"x3"];
        }];
        
        return nil;
    }];
    
    RACSignal *signal2 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [[RACScheduler mainThreadScheduler] afterDelay:0.3 schedule:^{
            [subscriber sendNext:@"y1"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:0.5 schedule:^{
            [subscriber sendNext:@"y2"];
        }];
        [[RACScheduler mainThreadScheduler] afterDelay:2.5 schedule:^{
            [subscriber sendNext:@"y3"];
        }];
        
        return nil;
    }];
    
    [[signal1 takeUntilReplacement:signal2]
     subscribeNext:^(id x) {
         NSLog(@"takeUntilReplacement -- %@", x);
     }];
    
    // 保证上面的延时操作得以完成
    [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        return nil;
    }] asynchronouslyWaitUntilCompleted:nil];
    
    // 打印日志
    /*
     2018-08-04 00:37:20.549201+0800 TestSignalOperationMethod[66655:6237414] takeUntilReplacement -- x1
     2018-08-04 00:37:20.851443+0800 TestSignalOperationMethod[66655:6237414] takeUntilReplacement -- y1
     2018-08-04 00:37:21.051631+0800 TestSignalOperationMethod[66655:6237414] takeUntilReplacement -- y2
     2018-08-04 00:37:23.051636+0800 TestSignalOperationMethod[66655:6237414] takeUntilReplacement -- y3
     */
}

@end
