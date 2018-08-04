# RACSignal+Operations方法（一）
### 这次分析下`RACSignal+Operations`里面的方法，由于里面的方法太多了，所以拆分成两篇分析。

#### 下面各个方法的测试用例[在这里](https://github.com/jianghui1/TestSignalOperationMethod)。

像`doNext:` `doError:` `doCompleted:`在[这边文章](https://blog.csdn.net/jianghui12138/article/details/81166583)中已经分析过了，没有看过的请去看一下，接下来按照顺序分析其他方法。

***
        
    - (RACSignal *)throttle:(NSTimeInterval)interval {
    	return [[self throttle:interval valuesPassingTest:^(id _) {
    		return YES;
    	}] setNameWithFormat:@"[%@] -throttle: %f", self.name, (double)interval];
    }
    
    - (RACSignal *)throttle:(NSTimeInterval)interval valuesPassingTest:(BOOL (^)(id next))predicate {
    	NSCParameterAssert(interval >= 0);
    	NSCParameterAssert(predicate != nil);
    
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];
    
    		// We may never use this scheduler, but we need to set it up ahead of
    		// time so that our scheduled blocks are run serially if we do.
    		RACScheduler *scheduler = [RACScheduler scheduler];
    
    		// Information about any currently-buffered `next` event.
    		__block id nextValue = nil;
    		__block BOOL hasNextValue = NO;
    		RACSerialDisposable *nextDisposable = [[RACSerialDisposable alloc] init];
    
    		void (^flushNext)(BOOL send) = ^(BOOL send) {
    			@synchronized (compoundDisposable) {
    				[nextDisposable.disposable dispose];
    
    				if (!hasNextValue) return;
    				if (send) [subscriber sendNext:nextValue];
    
    				nextValue = nil;
    				hasNextValue = NO;
    			}
    		};
    
    		RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
    			RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler;
    			BOOL shouldThrottle = predicate(x);
    
    			@synchronized (compoundDisposable) {
    				flushNext(NO);
    				if (!shouldThrottle) {
    					[subscriber sendNext:x];
    					return;
    				}
    
    				nextValue = x;
    				hasNextValue = YES;
    				nextDisposable.disposable = [delayScheduler afterDelay:interval schedule:^{
    					flushNext(YES);
    				}];
    			}
    		} error:^(NSError *error) {
    			[compoundDisposable dispose];
    			[subscriber sendError:error];
    		} completed:^{
    			flushNext(YES);
    			[subscriber sendCompleted];
    		}];
    
    		[compoundDisposable addDisposable:subscriptionDisposable];
    		return compoundDisposable;
    	}] setNameWithFormat:@"[%@] -throttle: %f valuesPassingTest:", self.name, (double)interval];
    }
首先看下比较长的`throttle:valuesPassingTest:`方法，
1. 创建一个`compoundDisposable`。
2. 创建一个`scheduler`对象，注释说这个对象可能不会使用到，后面代码会看到这个对象具体是怎么使用的。
3. 创建临时变量`nextValue` `hasNextValue` `nextDisposable`。
4. 定义一个`flushNext` block块，通过参数`send`判断是否发送信号的值。
5. 这一步就是对源信号的订阅：
* 首先检测当前是否有`currentScheduler`对象，没有的话就使用第二步创建的`scheduler`。所以第二步里面的注释部分说这个对象可能不会使用到。
* `subscribeNext`调用`predicate(x)`获取到一个判断条件，然后调用`flushNext(NO)`，再通过`predicate(x)`判断是否应该立即发送值。这里如果`shouldThrottle`为`NO`，就会立即将值发送出去；如果为`YES`，会通过`afterDelay:interval`延迟`interval`之后发送信号值。并通过第三步中创建的`nextDisposable`保存这个任务，用于在`flushNext`块中取消上次延时发送信号值的任务。
* `error`中就是正常的错误处理。
* `completed`中通过调用`flushNext(YES);`取消到之前的任务，然后发送完成信息。

##### 这就是这个方法的作用，通过`interval`设置一个信号值发送的延时时间。然后通过`(BOOL (^)(id next))predicate`作为判断哪些信号值应当被延时发送，如果在`interval`内有新的值，便会取消掉之前延时的任务，也就是把之前的值给舍去掉，如果在`interval`内信号完成，就会直接发送最后一个值并发送完成信号;而如果新值或者完成信息在`interval`内没有到来，就会发送延时任务值，达到`interval`内发送一次的效果。也就是节流。

而`throttle`方法就是将信号的所有信号值都延时发送，也就是对所有的值都进行节流。
***

    - (RACSignal *)delay:(NSTimeInterval)interval {
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
    
    		// We may never use this scheduler, but we need to set it up ahead of
    		// time so that our scheduled blocks are run serially if we do.
    		RACScheduler *scheduler = [RACScheduler scheduler];
    
    		void (^schedule)(dispatch_block_t) = ^(dispatch_block_t block) {
    			RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler;
    			RACDisposable *schedulerDisposable = [delayScheduler afterDelay:interval schedule:block];
    			[disposable addDisposable:schedulerDisposable];
    		};
    
    		RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
    			schedule(^{
    				[subscriber sendNext:x];
    			});
    		} error:^(NSError *error) {
    			[subscriber sendError:error];
    		} completed:^{
    			schedule(^{
    				[subscriber sendCompleted];
    			});
    		}];
    
    		[disposable addDisposable:subscriptionDisposable];
    		return disposable;
    	}] setNameWithFormat:@"[%@] -delay: %f", self.name, (double)interval];
    }
通过名字`delay`可以知道是延时，那与上面的方法有什么区别呢。其实这个方法就是将信号所有的信息都延时发送，包括`value` `error` `completed`。而延时是通过`schedule` block块实现的。
***

    - (RACSignal *)repeat {
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		return subscribeForever(self,
    			^(id x) {
    				[subscriber sendNext:x];
    			},
    			^(NSError *error, RACDisposable *disposable) {
    				[disposable dispose];
    				[subscriber sendError:error];
    			},
    			^(RACDisposable *disposable) {
    				// Resubscribe.
    			});
    	}] setNameWithFormat:@"[%@] -repeat", self.name];
    }
`repeat`即是重复。通过`subscribeForever`函数实现。
    
    static RACDisposable *subscribeForever (RACSignal *signal, void (^next)(id), void (^error)(NSError *, RACDisposable *), void (^completed)(RACDisposable *)) {
    	next = [next copy];
    	error = [error copy];
    	completed = [completed copy];
    
    	RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];
    
    	RACSchedulerRecursiveBlock recursiveBlock = ^(void (^recurse)(void)) {
    		RACCompoundDisposable *selfDisposable = [RACCompoundDisposable compoundDisposable];
    		[compoundDisposable addDisposable:selfDisposable];
    
    		__weak RACDisposable *weakSelfDisposable = selfDisposable;
    
    		RACDisposable *subscriptionDisposable = [signal subscribeNext:next error:^(NSError *e) {
    			@autoreleasepool {
    				error(e, compoundDisposable);
    				[compoundDisposable removeDisposable:weakSelfDisposable];
    			}
    
    			recurse();
    		} completed:^{
    			@autoreleasepool {
    				completed(compoundDisposable);
    				[compoundDisposable removeDisposable:weakSelfDisposable];
    			}
    
    			recurse();
    		}];
    
    		[selfDisposable addDisposable:subscriptionDisposable];
    	};
    
    	// Subscribe once immediately, and then use recursive scheduling for any
    	// further resubscriptions.
    	recursiveBlock(^{
    		RACScheduler *recursiveScheduler = RACScheduler.currentScheduler ?: [RACScheduler scheduler];
    
    		RACDisposable *schedulingDisposable = [recursiveScheduler scheduleRecursiveBlock:recursiveBlock];
    		[compoundDisposable addDisposable:schedulingDisposable];
    	});
    
    	return compoundDisposable;
    }
该函数中定义了一个`recursiveBlock`块，在该块中，通过对`signal`进行订阅，并在`error:` `completed:`通过调用`recurse()`使参数`void (^recurse)(void)`重复执行。

##### 到这里可以知道，`recursiveBlock`的执行才会导致信号的订阅。

接下来就调用`recursiveBlock`开始了对源信号的一次订阅。里面又使用了`RACScheduler`的`scheduleRecursiveBlock:`方法，代码如下：
    
    - (RACDisposable *)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock {
    	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
    
    	[self scheduleRecursiveBlock:[recursiveBlock copy] addingToDisposable:disposable];
    	return disposable;
    }
    
    - (void)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock addingToDisposable:(RACCompoundDisposable *)disposable {
    	@autoreleasepool {
    		RACCompoundDisposable *selfDisposable = [RACCompoundDisposable compoundDisposable];
    		[disposable addDisposable:selfDisposable];
    
    		__weak RACDisposable *weakSelfDisposable = selfDisposable;
    
    		RACDisposable *schedulingDisposable = [self schedule:^{
    			@autoreleasepool {
    				// At this point, we've been invoked, so our disposable is now useless.
    				[disposable removeDisposable:weakSelfDisposable];
    			}
    
    			if (disposable.disposed) return;
    
    			void (^reallyReschedule)(void) = ^{
    				if (disposable.disposed) return;
    				[self scheduleRecursiveBlock:recursiveBlock addingToDisposable:disposable];
    			};
    
    			// Protects the variables below.
    			//
    			// This doesn't actually need to be __block qualified, but Clang
    			// complains otherwise. :C
    			__block NSLock *lock = [[NSLock alloc] init];
    			lock.name = [NSString stringWithFormat:@"%@ %s", self, sel_getName(_cmd)];
    
    			__block NSUInteger rescheduleCount = 0;
    
    			// Set to YES once synchronous execution has finished. Further
    			// rescheduling should occur immediately (rather than being
    			// flattened).
    			__block BOOL rescheduleImmediately = NO;
    
    			@autoreleasepool {
    				recursiveBlock(^{
    					[lock lock];
    					BOOL immediate = rescheduleImmediately;
    					if (!immediate) ++rescheduleCount;
    					[lock unlock];
    
    					if (immediate) reallyReschedule();
    				});
    			}
    
    			[lock lock];
    			NSUInteger synchronousCount = rescheduleCount;
    			rescheduleImmediately = YES;
    			[lock unlock];
    
    			for (NSUInteger i = 0; i < synchronousCount; i++) {
    				reallyReschedule();
    			}
    		}];
    
    		[selfDisposable addDisposable:schedulingDisposable];
    	}
    }
在`scheduleRecursiveBlock:addingToDisposable`中，通过`reallyReschedule`块递归调用`scheduleRecursiveBlock:addingToDisposable`函数本身。函数中又会调用`recursiveBlock`块，通过`immediate`来判断是立即执行，还是通过`rescheduleCount`叠加起来，通过`for`循环调用`reallyReschedule()`块。

这里逻辑是比较复杂的，所以将步骤拆分一下。

下面就按照顺序将各个变量、block对应起来。
1. 在`subscribeForever`函数中`RACSchedulerRecursiveBlock recursiveBlock = ^(void (^recurse)(void))`中的`recurse`对应于

    	RACScheduler *recursiveScheduler = RACScheduler.currentScheduler ?: [RACScheduler scheduler];
    
    	RACDisposable *schedulingDisposable = [recursiveScheduler scheduleRecursiveBlock:recursiveBlock];
    	[compoundDisposable addDisposable:schedulingDisposable];
    所以当调用`recursiveBlock`的时候，就会对`signal`进行订阅，等到信号`error:` `completed:`时，调用`recurse()`即是执行`scheduleRecursiveBlock:`函数。
2. `scheduleRecursiveBlock`方法的参数就是`recursiveBlock`块。在`scheduleRecursiveBlock:addingToDisposable:`函数中，有`recursiveBlock()`块的调用，即对信号`signal`进行订阅。注意此时`recursiveBlock`中的`recurse`块已经发生了变化，变成了

        [lock lock];
		BOOL immediate = rescheduleImmediately;
		if (!immediate) ++rescheduleCount;
		[lock unlock];

		if (immediate) reallyReschedule();
也就是通过`reallyReschedule`完成对`scheduleRecursiveBlock:addingToDisposable:`函数的自身递归调用。一旦函数继续调用，便会继续调用`reallyReschedule`，也就保证了对原始信号`signal`的重复订阅。

注意，这里必须要明确一点，就是只有`recursiveBlock()`块中代码执行了，才会调用`reallyReschedule()`。因为下面`for`循环中的`rescheduleCount`也是在`recursiveBlock`块中自增的。由于`recursiveBlock()`块中`reallyReschedule()`代码和`for`中的`reallyReschedule()`所在线程不同，所以要看这两者的执行顺序了。

* 如果`recursiveBlock()`中代码先执行的话，此时`rescheduleImmediately`可以为YES也可以为NO。如果为NO，不会执行`reallyReschedule()`,然后会通过下面的`for`循环执行`reallyReschedule()`；如果为YES，这时候就会直接调用`reallyReschedule()`，下面的`for`循环就不会调用了。所以这种情况下`reallyReschedule()`都是在`recursiveBlock()`中block执行之后调用的。这样就保证了信号结束之后的重复订阅。

* 如果`for`循环先调用的话，此时`rescheduleCount`为0，不会执行`reallyReschedule()`。最终`reallyReschedule()`的执行还是发生在`recursiveBlock`中。还是保证了信号结束之后的重复订阅。

既然都是保证信号结束之后的重复订阅，为什么不直接在`recursiveBlock`块中直接调用`reallyReschedule`，而去加锁和for循环呢？

由于刚才也说了`recursiveBlock`块中的代码和`for`循环并不是在同一个线程，可能就是为了发挥出多线程的优势吧。

所以以上两种情况下，都是在源信号订阅完成或者出错之后，重新订阅源信号，也就是让源信号一遍一遍的重复。

##### 上面算是把`repeat`方法分析了一遍，总得来说，就是对信号完成重复性的订阅。
***

    - (RACSignal *)catch:(RACSignal * (^)(NSError *error))catchBlock {
    	NSCParameterAssert(catchBlock != NULL);
    
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		RACSerialDisposable *catchDisposable = [[RACSerialDisposable alloc] init];
    
    		RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
    			[subscriber sendNext:x];
    		} error:^(NSError *error) {
    			RACSignal *signal = catchBlock(error);
    			NSCAssert(signal != nil, @"Expected non-nil signal from catch block on %@", self);
    			catchDisposable.disposable = [signal subscribe:subscriber];
    		} completed:^{
    			[subscriber sendCompleted];
    		}];
    
    		return [RACDisposable disposableWithBlock:^{
    			[catchDisposable dispose];
    			[subscriptionDisposable dispose];
    		}];
    	}] setNameWithFormat:@"[%@] -catch:", self.name];
    }
通过`catchBlock`获取一个`signal`，等到源信号发生错误的时候，对该`signal`进行订阅。
***

    - (RACSignal *)catchTo:(RACSignal *)signal {
    	return [[self catch:^(NSError *error) {
    		return signal;
    	}] setNameWithFormat:@"[%@] -catchTo: %@", self.name, signal];
    }
通过调用`catch:`方法，当源信号出错时完成对`signal`的订阅。
***

    - (RACSignal *)try:(BOOL (^)(id value, NSError **errorPtr))tryBlock {
    	NSCParameterAssert(tryBlock != NULL);
    
    	return [[self flattenMap:^(id value) {
    		NSError *error = nil;
    		BOOL passed = tryBlock(value, &error);
    		return (passed ? [RACSignal return:value] : [RACSignal error:error]);
    	}] setNameWithFormat:@"[%@] -try:", self.name];
    }
通过`tryBlock`控制源信号值的处理,返回信号值，或者错误值。
***

    - (RACSignal *)tryMap:(id (^)(id value, NSError **errorPtr))mapBlock {
    	NSCParameterAssert(mapBlock != NULL);
    
    	return [[self flattenMap:^(id value) {
    		NSError *error = nil;
    		id mappedValue = mapBlock(value, &error);
    		return (mappedValue == nil ? [RACSignal error:error] : [RACSignal return:mappedValue]);
    	}] setNameWithFormat:@"[%@] -tryMap:", self.name];
    }
通过`mapBlock`获取对值的处理，如果返回值存在，返回对源信号值的处理结果，否则返回错误信息。
***

    - (RACSignal *)initially:(void (^)(void))block {
    	NSCParameterAssert(block != NULL);
    
    	return [[RACSignal defer:^{
    		block();
    		return self;
    	}] setNameWithFormat:@"[%@] -initially:", self.name];
    }
    + (RACSignal *)defer:(RACSignal * (^)(void))block {
    	NSCParameterAssert(block != NULL);
    
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		return [block() subscribe:subscriber];
    	}] setNameWithFormat:@"+defer:"];
    }
首先`defer:`方法完成对`block()`获得信号的订阅。

然后`initially:`通过调用`defer:`方法保证`block`优先被调用。
***

    - (RACSignal *)finally:(void (^)(void))block {
    	NSCParameterAssert(block != NULL);
    
    	return [[[self
    		doError:^(NSError *error) {
    			block();
    		}]
    		doCompleted:^{
    			block();
    		}]
    		setNameWithFormat:@"[%@] -finally:", self.name];
    }
通过`doError` `doCompleted`在信号结束的时候执行`block()`。
***

    - (RACSignal *)bufferWithTime:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
    	NSCParameterAssert(scheduler != nil);
    	NSCParameterAssert(scheduler != RACScheduler.immediateScheduler);
    
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		RACSerialDisposable *timerDisposable = [[RACSerialDisposable alloc] init];
    		NSMutableArray *values = [NSMutableArray array];
    
    		void (^flushValues)() = ^{
    			@synchronized (values) {
    				[timerDisposable.disposable dispose];
    
    				if (values.count == 0) return;
    
    				RACTuple *tuple = [RACTuple tupleWithObjectsFromArray:values];
    				[values removeAllObjects];
    				[subscriber sendNext:tuple];
    			}
    		};
    
    		RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
    			@synchronized (values) {
    				if (values.count == 0) {
    					timerDisposable.disposable = [scheduler afterDelay:interval schedule:flushValues];
    				}
    
    				[values addObject:x ?: RACTupleNil.tupleNil];
    			}
    		} error:^(NSError *error) {
    			[subscriber sendError:error];
    		} completed:^{
    			flushValues();
    			[subscriber sendCompleted];
    		}];
    
    		return [RACDisposable disposableWithBlock:^{
    			[selfDisposable dispose];
    			[timerDisposable dispose];
    		}];
    	}] setNameWithFormat:@"[%@] -bufferWithTime: %f onScheduler: %@", self.name, (double)interval, scheduler];
    }
该方法会将在`interval`间隔内获取的信号值缓存起来一块发送。
***

    - (RACSignal *)collect {
    	return [[self aggregateWithStartFactory:^{
    		return [[NSMutableArray alloc] init];
    	} reduce:^(NSMutableArray *collectedValues, id x) {
    		[collectedValues addObject:(x ?: NSNull.null)];
    		return collectedValues;
    	}] setNameWithFormat:@"[%@] -collect", self.name];
    }
    
    - (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory reduce:(id (^)(id running, id next))reduceBlock {
    	NSCParameterAssert(startFactory != NULL);
    	NSCParameterAssert(reduceBlock != NULL);
    
    	return [[RACSignal defer:^{
    		return [self aggregateWithStart:startFactory() reduce:reduceBlock];
    	}] setNameWithFormat:@"[%@] -aggregateWithStartFactory:reduce:", self.name];
    }
    
    - (RACSignal *)aggregateWithStart:(id)start reduce:(id (^)(id running, id next))reduceBlock {
    	return [[self
    		aggregateWithStart:start
    		reduceWithIndex:^(id running, id next, NSUInteger index) {
    			return reduceBlock(running, next);
    		}]
    		setNameWithFormat:@"[%@] -aggregateWithStart: %@ reduce:", self.name, [start rac_description]];
    }
    
    - (RACSignal *)aggregateWithStart:(id)start reduceWithIndex:(id (^)(id, id, NSUInteger))reduceBlock {
    	return [[[[self
    		scanWithStart:start reduceWithIndex:reduceBlock]
    		startWith:start]
    		takeLast:1]
    		setNameWithFormat:@"[%@] -aggregateWithStart: %@ reduceWithIndex:", self.name, [start rac_description]];
    }
    - (RACSignal *)takeLast:(NSUInteger)count {
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		NSMutableArray *valuesTaken = [NSMutableArray arrayWithCapacity:count];
    		return [self subscribeNext:^(id x) {
    			[valuesTaken addObject:x ? : RACTupleNil.tupleNil];
    
    			while (valuesTaken.count > count) {
    				[valuesTaken removeObjectAtIndex:0];
    			}
    		} error:^(NSError *error) {
    			[subscriber sendError:error];
    		} completed:^{
    			for (id value in valuesTaken) {
    				[subscriber sendNext:value == RACTupleNil.tupleNil ? nil : value];
    			}
    
    			[subscriber sendCompleted];
    		}];
    	}] setNameWithFormat:@"[%@] -takeLast: %lu", self.name, (unsigned long)count];
    }

按照从下至上的顺序看这些函数。
* `takeLast:`通过`count`来确定要发送最后几个信号值。
* `aggregateWithStart:reduceWithIndex:`。[这篇文章](https://blog.csdn.net/jianghui12138/article/details/81003630)讲了`scanWithStart:reduceWithIndex:`的作用：就是将前后值通过`reduceBlock`运算并作为前值，与后来的值通过`reduceBlock`计算，循环往复。然后通过`startWith:`保证将`start`作为最开始的默认值，最后通过`takeLast`获取信号最后的一个值。
* `aggregateWithStart:reduce`调用上面的方法，只是`reduceBlock`相较上面方法的`reduceBlock`少了一个参数。
* `aggregateWithStartFactory:reduce:`通过调用`defer:`和上面的方法，将`startFactory()`作为初始值，`reduceBlock`作为运算规则。
* `collect`通过调用上面的方法，将`[[NSMutableArray alloc] init];`作为初始值，`[collectedValues addObject:(x ?: NSNull.null)];`作为运算规则，所以最终返回了一个所有信号值组成的一个数组。
***

    - (RACSignal *)combineLatestWith:(RACSignal *)signal {
    	NSCParameterAssert(signal != nil);
    
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
    
    		__block id lastSelfValue = nil;
    		__block BOOL selfCompleted = NO;
    
    		__block id lastOtherValue = nil;
    		__block BOOL otherCompleted = NO;
    
    		void (^sendNext)(void) = ^{
    			@synchronized (disposable) {
    				if (lastSelfValue == nil || lastOtherValue == nil) return;
    				[subscriber sendNext:RACTuplePack(lastSelfValue, lastOtherValue)];
    			}
    		};
    
    		RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
    			@synchronized (disposable) {
    				lastSelfValue = x ?: RACTupleNil.tupleNil;
    				sendNext();
    			}
    		} error:^(NSError *error) {
    			[subscriber sendError:error];
    		} completed:^{
    			@synchronized (disposable) {
    				selfCompleted = YES;
    				if (otherCompleted) [subscriber sendCompleted];
    			}
    		}];
    
    		[disposable addDisposable:selfDisposable];
    
    		RACDisposable *otherDisposable = [signal subscribeNext:^(id x) {
    			@synchronized (disposable) {
    				lastOtherValue = x ?: RACTupleNil.tupleNil;
    				sendNext();
    			}
    		} error:^(NSError *error) {
    			[subscriber sendError:error];
    		} completed:^{
    			@synchronized (disposable) {
    				otherCompleted = YES;
    				if (selfCompleted) [subscriber sendCompleted];
    			}
    		}];
    
    		[disposable addDisposable:otherDisposable];
    
    		return disposable;
    	}] setNameWithFormat:@"[%@] -combineLatestWith: %@", self.name, signal];
    }
该方法对于值的发送是通过`sendNext`block块来实现的，里面通过`lastSelfValue` `lastOtherValue`保存源信号与`signal`的值，并将它们封装成一个元祖发送出去，最终的效果就是保证源信号与`signal`最新值的结合。而`sendCompleted`则是两个信号都完成之后才进行的操作。
***
    + (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals {
    	return [[self join:signals block:^(RACSignal *left, RACSignal *right) {
    		return [left combineLatestWith:right];
    	}] setNameWithFormat:@"+combineLatest: %@", signals];
    }
通过`join:block`将`signals`以`[left combineLatestWith:right];`结合起来，最终获取到所有信号最新值组成的元祖。
***

    + (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id (^)())reduceBlock {
    	NSCParameterAssert(reduceBlock != nil);
    
    	RACSignal *result = [self combineLatest:signals];
    
    	// Although we assert this condition above, older versions of this method
    	// supported this argument being nil. Avoid crashing Release builds of
    	// apps that depended on that.
    	if (reduceBlock != nil) result = [result reduceEach:reduceBlock];
    
    	return [result setNameWithFormat:@"+combineLatest: %@ reduce:", signals];
    }
先调用`combineLatest`将所有信号组成起来，然后以这些值为参数通过`reduceEach:`获取一个返回值。
***

    - (RACSignal *)merge:(RACSignal *)signal {
    	return [[RACSignal
    		merge:@[ self, signal ]]
    		setNameWithFormat:@"[%@] -merge: %@", self.name, signal];
    }
    
    + (RACSignal *)merge:(id<NSFastEnumeration>)signals {
    	NSMutableArray *copiedSignals = [[NSMutableArray alloc] init];
    	for (RACSignal *signal in signals) {
    		[copiedSignals addObject:signal];
    	}
    
    	return [[[RACSignal
    		createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
    			for (RACSignal *signal in copiedSignals) {
    				[subscriber sendNext:signal];
    			}
    
    			[subscriber sendCompleted];
    			return nil;
    		}]
    		flatten]
    		setNameWithFormat:@"+merge: %@", copiedSignals];
    }
* `+merge:`首先将多个信号保存到数组中，再通过`flatten`完成对多个信号的有序组合以备订阅。
* `-merge:`将两个信号有序组合以备订阅。
***

    - (RACSignal *)flatten:(NSUInteger)maxConcurrent {
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		RACCompoundDisposable *compoundDisposable = [[RACCompoundDisposable alloc] init];
    
    		// Contains disposables for the currently active subscriptions.
    		//
    		// This should only be used while synchronized on `subscriber`.
    		NSMutableArray *activeDisposables = [[NSMutableArray alloc] initWithCapacity:maxConcurrent];
    
    		// Whether the signal-of-signals has completed yet.
    		//
    		// This should only be used while synchronized on `subscriber`.
    		__block BOOL selfCompleted = NO;
    
    		// Subscribes to the given signal.
    		__block void (^subscribeToSignal)(RACSignal *);
    
    		// Weak reference to the above, to avoid a leak.
    		__weak __block void (^recur)(RACSignal *);
    
    		// Sends completed to the subscriber if all signals are finished.
    		//
    		// This should only be used while synchronized on `subscriber`.
    		void (^completeIfAllowed)(void) = ^{
    			if (selfCompleted && activeDisposables.count == 0) {
    				[subscriber sendCompleted];
    
    				// A strong reference is held to `subscribeToSignal` until completion,
    				// preventing it from deallocating early.
    				subscribeToSignal = nil;
    			}
    		};
    
    		// The signals waiting to be started.
    		//
    		// This array should only be used while synchronized on `subscriber`.
    		NSMutableArray *queuedSignals = [NSMutableArray array];
    
    		recur = subscribeToSignal = ^(RACSignal *signal) {
    			RACSerialDisposable *serialDisposable = [[RACSerialDisposable alloc] init];
    
    			@synchronized (subscriber) {
    				[compoundDisposable addDisposable:serialDisposable];
    				[activeDisposables addObject:serialDisposable];
    			}
    
    			serialDisposable.disposable = [signal subscribeNext:^(id x) {
    				[subscriber sendNext:x];
    			} error:^(NSError *error) {
    				[subscriber sendError:error];
    			} completed:^{
    				__strong void (^subscribeToSignal)(RACSignal *) = recur;
    				RACSignal *nextSignal;
    
    				@synchronized (subscriber) {
    					[compoundDisposable removeDisposable:serialDisposable];
    					[activeDisposables removeObjectIdenticalTo:serialDisposable];
    
    					if (queuedSignals.count == 0) {
    						completeIfAllowed();
    						return;
    					}
    
    					nextSignal = queuedSignals[0];
    					[queuedSignals removeObjectAtIndex:0];
    				}
    
    				subscribeToSignal(nextSignal);
    			}];
    		};
    
    		[compoundDisposable addDisposable:[self subscribeNext:^(RACSignal *signal) {
    			if (signal == nil) return;
    
    			NSCAssert([signal isKindOfClass:RACSignal.class], @"Expected a RACSignal, got %@", signal);
    
    			@synchronized (subscriber) {
    				if (maxConcurrent > 0 && activeDisposables.count >= maxConcurrent) {
    					[queuedSignals addObject:signal];
    
    					// If we need to wait, skip subscribing to this
    					// signal.
    					return;
    				}
    			}
    
    			subscribeToSignal(signal);
    		} error:^(NSError *error) {
    			[subscriber sendError:error];
    		} completed:^{
    			@synchronized (subscriber) {
    				selfCompleted = YES;
    				completeIfAllowed();
    			}
    		}]];
    
    		return compoundDisposable;
    	}] setNameWithFormat:@"[%@] -flatten: %lu", self.name, (unsigned long)maxConcurrent];
    }
参数`maxConcurrent`决定了当前可以用来被订阅的最大信号数。通过`completeIfAllowed`块来处理信号的完成。`recur` `subscribeToSignal`完成对参数`signal`的订阅，如果`signal`完成，此时如果源信号也完成，就发送完成信息；如果源信号没有完成，就将`signal`从当前的信号数组`activeDisposables`中移除，以便源信号值再次添加到当前信号数组`activeDisposables`中。而源信号的订阅中，会根据`maxConcurrent > 0 && activeDisposables.count >= maxConcurrent`判断对`signal`进行订阅还是舍弃。

所以此方法就是保证同时进行最大`maxConcurrent`个信号的订阅。
***

    - (RACSignal *)then:(RACSignal * (^)(void))block {
    	NSCParameterAssert(block != nil);
    
    	return [[[self
    		ignoreValues]
    		concat:[RACSignal defer:block]]
    		setNameWithFormat:@"[%@] -then:", self.name];
    }
    - (RACSignal *)ignoreValues {
    	return [[self filter:^(id _) {
    		return NO;
    	}] setNameWithFormat:@"[%@] -ignoreValues", self.name];
    }
`ignoreValues`调用`filter:`忽略所有的信号值。

`then:`先调用`ignoreValues`忽略掉所有的信号值，然后通过`[RACSignal defer:block]`获取一个新的信号，最后通过`concat:`将两者连接起来。也就是源信号订阅结束之后开始`block`获取的信号的订阅。

注意：`merge`是将两个或多个信号有序订阅，可能这些信号的订阅同时进行着。而`concat：`是将两个信号连接起来，一个订阅完成，才开始另一个的订阅。
***

    - (RACSignal *)concat {
    	return [[self flatten:1] setNameWithFormat:@"[%@] -concat", self.name];
    }
通过调用`flatten:1`保证当前订阅的信号数为1，也就是一个订阅完成，才开始新的订阅。

其实，`merge`就相当于并行，而`concat`就相当于串行。
***
    
    - (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object {
    	return [self setKeyPath:keyPath onObject:object nilValue:nil];
    }
    
    - (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object nilValue:(id)nilValue {
    	NSCParameterAssert(keyPath != nil);
    	NSCParameterAssert(object != nil);
    
    	keyPath = [keyPath copy];
    
    	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
    
    	// Purposely not retaining 'object', since we want to tear down the binding
    	// when it deallocates normally.
    	__block void * volatile objectPtr = (__bridge void *)object;
    
    	RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
    		// Possibly spec, possibly compiler bug, but this __bridge cast does not
    		// result in a retain here, effectively an invisible __unsafe_unretained
    		// qualifier. Using objc_precise_lifetime gives the __strong reference
    		// desired. The explicit use of __strong is strictly defensive.
    		__strong NSObject *object __attribute__((objc_precise_lifetime)) = (__bridge __strong id)objectPtr;
    		[object setValue:x ?: nilValue forKeyPath:keyPath];
    	} error:^(NSError *error) {
    		__strong NSObject *object __attribute__((objc_precise_lifetime)) = (__bridge __strong id)objectPtr;
    
    		NSCAssert(NO, @"Received error from %@ in binding for key path \"%@\" on %@: %@", self, keyPath, object, error);
    
    		// Log the error if we're running with assertions disabled.
    		NSLog(@"Received error from %@ in binding for key path \"%@\" on %@: %@", self, keyPath, object, error);
    
    		[disposable dispose];
    	} completed:^{
    		[disposable dispose];
    	}];
    
    	[disposable addDisposable:subscriptionDisposable];
    
    	#if DEBUG
    	static void *bindingsKey = &bindingsKey;
    	NSMutableDictionary *bindings;
    
    	@synchronized (object) {
    		bindings = objc_getAssociatedObject(object, bindingsKey);
    		if (bindings == nil) {
    			bindings = [NSMutableDictionary dictionary];
    			objc_setAssociatedObject(object, bindingsKey, bindings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    		}
    	}
    
    	@synchronized (bindings) {
    		NSCAssert(bindings[keyPath] == nil, @"Signal %@ is already bound to key path \"%@\" on object %@, adding signal %@ is undefined behavior", [bindings[keyPath] nonretainedObjectValue], keyPath, object, self);
    
    		bindings[keyPath] = [NSValue valueWithNonretainedObject:self];
    	}
    	#endif
    
    	RACDisposable *clearPointerDisposable = [RACDisposable disposableWithBlock:^{
    		#if DEBUG
    		@synchronized (bindings) {
    			[bindings removeObjectForKey:keyPath];
    		}
    		#endif
    
    		while (YES) {
    			void *ptr = objectPtr;
    			if (OSAtomicCompareAndSwapPtrBarrier(ptr, NULL, &objectPtr)) {
    				break;
    			}
    		}
    	}];
    
    	[disposable addDisposable:clearPointerDisposable];
    
    	[object.rac_deallocDisposable addDisposable:disposable];
    
    	RACCompoundDisposable *objectDisposable = object.rac_deallocDisposable;
    	return [RACDisposable disposableWithBlock:^{
    		[objectDisposable removeDisposable:disposable];
    		[disposable dispose];
    	}];
    }
`setKeyPath:onObject:nilValue:`的功能就是对源信号进行订阅，将信号的值通过kvc的方式赋值给`object`的`keyPath`。并提供一个`nilValue`作为空值的替代值。

而`setKeyPath:onObject:`通过调用`setKeyPath:onObject:nilValue:`将`nil`作为信号值为空下的替代值。
***

    + (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
    	return [[RACSignal interval:interval onScheduler:scheduler withLeeway:0.0] setNameWithFormat:@"+interval: %f onScheduler: %@", (double)interval, scheduler];
    }
    
    + (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler withLeeway:(NSTimeInterval)leeway {
    	NSCParameterAssert(scheduler != nil);
    	NSCParameterAssert(scheduler != RACScheduler.immediateScheduler);
    
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		return [scheduler after:[NSDate dateWithTimeIntervalSinceNow:interval] repeatingEvery:interval withLeeway:leeway schedule:^{
    			[subscriber sendNext:[NSDate date]];
    		}];
    	}] setNameWithFormat:@"+interval: %f onScheduler: %@ withLeeway: %f", (double)interval, scheduler, (double)leeway];
    }
    
    // RACQueueScheduler.m
    - (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block {
    	NSCParameterAssert(date != nil);
    	NSCParameterAssert(interval > 0.0 && interval < INT64_MAX / NSEC_PER_SEC);
    	NSCParameterAssert(leeway >= 0.0 && leeway < INT64_MAX / NSEC_PER_SEC);
    	NSCParameterAssert(block != NULL);
    
    	uint64_t intervalInNanoSecs = (uint64_t)(interval * NSEC_PER_SEC);
    	uint64_t leewayInNanoSecs = (uint64_t)(leeway * NSEC_PER_SEC);
    
    	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    	dispatch_source_set_timer(timer, [self.class wallTimeWithDate:date], intervalInNanoSecs, leewayInNanoSecs);
    	dispatch_source_set_event_handler(timer, block);
    	dispatch_resume(timer);
    
    	return [RACDisposable disposableWithBlock:^{
    		dispatch_source_cancel(timer);
    	}];
    }
首先看下`RACQueueScheduler`的方法，通过gcd实现了一个计时器的功能。

`interval:onScheduler:withLeeway:`通过调用上面的方法实现一个可以指定时间间隔`interval`和时间容忍度`leeway`的定时器，并通过调度器`scheduler`确定计时器应该运行的线程。

而`interval:onScheduler:`只是将定时器的容忍值设为0。
***

    - (RACSignal *)takeUntil:(RACSignal *)signalTrigger {
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
    		void (^triggerCompletion)(void) = ^{
    			[disposable dispose];
    			[subscriber sendCompleted];
    		};
    
    		RACDisposable *triggerDisposable = [signalTrigger subscribeNext:^(id _) {
    			triggerCompletion();
    		} completed:^{
    			triggerCompletion();
    		}];
    
    		[disposable addDisposable:triggerDisposable];
    
    		if (!disposable.disposed) {
    			RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
    				[subscriber sendNext:x];
    			} error:^(NSError *error) {
    				[subscriber sendError:error];
    			} completed:^{
    				[disposable dispose];
    				[subscriber sendCompleted];
    			}];
    
    			[disposable addDisposable:selfDisposable];
    		}
    
    		return disposable;
    	}] setNameWithFormat:@"[%@] -takeUntil: %@", self.name, signalTrigger];
    }
该方法通过`signalTrigger`控制源信号订阅的结束。看`signalTrigger`的订阅，一旦有信号值或者该信号完成，就会调用`triggerCompletion()`，而`triggerCompletion`会做清理工作并发送完成信号，这时候源信号的订阅自然也就结束了。

所以，这个方法根据命名就可以理解，对源信号订阅直到`signalTrigger`有值或者完成。
***

    - (RACSignal *)takeUntilReplacement:(RACSignal *)replacement {
    	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		RACSerialDisposable *selfDisposable = [[RACSerialDisposable alloc] init];
    
    		RACDisposable *replacementDisposable = [replacement subscribeNext:^(id x) {
    			[selfDisposable dispose];
    			[subscriber sendNext:x];
    		} error:^(NSError *error) {
    			[selfDisposable dispose];
    			[subscriber sendError:error];
    		} completed:^{
    			[selfDisposable dispose];
    			[subscriber sendCompleted];
    		}];
    
    		if (!selfDisposable.disposed) {
    			selfDisposable.disposable = [[self
    				concat:[RACSignal never]]
    				subscribe:subscriber];
    		}
    
    		return [RACDisposable disposableWithBlock:^{
    			[selfDisposable dispose];
    			[replacementDisposable dispose];
    		}];
    	}];
    }
首先对`replacement`进行订阅，不管是`next:` `error:` `completed:` 都会调用`[selfDisposable dispose];`,而`selfDisposable`就是对源信号订阅时的清理对象，所以`replacement`跟上面一样，起到一个控制源信号订阅结束的功能。然后`replacement`订阅中又有`[subscriber sendNext:x];` `[subscriber sendError:error];` `[subscriber sendCompleted];`。

所以，正如其名字`takeUntilReplacement`,`takeUntil`跟上面一样，对源信号进行订阅直到`replacement`有值或者失败或者完成。然后`Replacement`的意思就是使用`replacement`的订阅信息作为源信号信息的替代，当`replacement`终结了源信号的订阅时，`replacement`会继续发送信息，作为源信号的替代。
