#import <Cephei/HBPreferences.h>
#import <objc/runtime.h>
#import <MRYIPCCenter.h>

#define TWEAK_NAME @"GrowingBadges"
#define BUNDLE [NSString stringWithFormat:@"com.wrp1002.%@", [TWEAK_NAME lowercaseString]]


//	=========================== Preference vars ===========================

BOOL enabled;
BOOL limitSize = true;
NSInteger maxNotifs = 100;

//	=========================== Other vars ===========================

int startupDelay = 5;
HBPreferences *preferences;
static MRYIPCCenter* center;

//	=========================== Debugging stuff ===========================

@interface Debug : NSObject
	+(UIWindow*)GetKeyWindow;
	+(void)ShowAlert:(NSString *)msg;
	+(void)Log:(NSString *)msg;
	+(void)LogException:(NSException *)e;
	+(void)SpringBoardReady;
@end

@implementation Debug
	static bool springboardReady = false;

	+(UIWindow*)GetKeyWindow {
		UIWindow        *foundWindow = nil;
		NSArray         *windows = [[UIApplication sharedApplication]windows];
		for (UIWindow   *window in windows) {
			if (window.isKeyWindow) {
				foundWindow = window;
				break;
			}
		}
		return foundWindow;
	}

	//	Shows an alert box. Used for debugging 
	+(void)ShowAlert:(NSString *)msg {
		if (!springboardReady) return;

		UIAlertController * alert = [UIAlertController
									alertControllerWithTitle:@"Alert"
									message:msg
									preferredStyle:UIAlertControllerStyleAlert];

		//Add Buttons
		UIAlertAction* dismissButton = [UIAlertAction
									actionWithTitle:@"Cool!"
									style:UIAlertActionStyleDefault
									handler:^(UIAlertAction * action) {
										//Handle dismiss button action here
										
									}];

		//Add your buttons to alert controller
		[alert addAction:dismissButton];

		[[self GetKeyWindow].rootViewController presentViewController:alert animated:YES completion:nil];
	}

	//	Show log with tweak name as prefix for easy grep
	+(void)Log:(NSString *)msg {
		NSLog(@"%@: %@", TWEAK_NAME, msg);
	}

	//	Log exception info
	+(void)LogException:(NSException *)e {
		NSLog(@"%@: NSException caught", TWEAK_NAME);
		NSLog(@"%@: Name:%@", TWEAK_NAME, e.name);
		NSLog(@"%@: Reason:%@", TWEAK_NAME, e.reason);
	}

	+(void)SpringBoardReady {
		springboardReady = true;
	}
@end


//	=========================== Classes / Functions ===========================


@interface SBIconBadgeView : UIView {
	NSString* _text;
}
-(CGPoint)accessoryCenterForIconBounds:(CGRect)arg1 ;
@end


//	=========================== Hooks ===========================

%group Hooks

	%hook SpringBoard

		//	Called when springboard is finished launching
		-(void)applicationDidFinishLaunching:(id)application {
			%orig;
			[Debug SpringBoardReady];
		}

	%end

	%hook SBIconBadgeView
		-(void)layoutSubviews {
			%orig;

			if (!enabled)
				return;

			NSString *text = MSHookIvar<NSString *>(self, "_text");
			NSString *replacedText = [text stringByReplacingOccurrencesOfString:@"," withString:@""];
			int notifs = [replacedText intValue];

			double percent = (double)notifs / (double)maxNotifs;
			if (limitSize && percent > 1.0)
				percent = 1.0;

			self.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1 + percent, 1 + percent);
		}

		-(CGPoint)accessoryCenterForIconBounds:(CGRect)arg1 {
			if (!enabled)
				return %orig;

			CGPoint pos = %orig;

			NSString *text = MSHookIvar<NSString *>(self, "_text");
			NSString *replacedText = [text stringByReplacingOccurrencesOfString:@"," withString:@""];
			int notifs = [replacedText intValue];

			double width = arg1.size.width;
			double height = arg1.size.height;
			double percent = (double)notifs / (double)maxNotifs;

			percent = percent * percent;
			
			[Debug Log:[NSString stringWithFormat:@"notifs:%d  percent:%f", notifs, percent]];
			[Debug Log:[NSString stringWithFormat:@"x:%f  y:%f", pos.x, pos.y]];
			[Debug Log:[NSString stringWithFormat:@"width:%f  height:%f", width, height]];
			[Debug Log:[NSString stringWithFormat:@"pos.x:%f  pos.y:%f", pos.x, pos.y]];;

			// calculate new position
			pos.x -= (pos.x - width / 2 ) * percent;
			pos.y -= (pos.y - height / 2) * percent;
			if (pos.x < 30)
				pos.x = 30;
			if (pos.y > 30)
				pos.y = 30;

			return pos;
		}

	%end
%end


//	=========================== Constructor stuff ===========================

%ctor {
	[Debug Log:[NSString stringWithFormat:@"============== %@ started ==============", TWEAK_NAME]];

	preferences = [[HBPreferences alloc] initWithIdentifier:BUNDLE];
	[preferences registerBool:&enabled default:true forKey:@"kEnabled"];
	[preferences registerBool:&limitSize default:true forKey:@"kLimitSize"];
	[preferences registerInteger:&maxNotifs default:100 forKey:@"kMaxNotifs"];

	%init(Hooks);
}
