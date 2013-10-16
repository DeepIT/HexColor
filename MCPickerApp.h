/* MCPickerApp */

#import <Cocoa/Cocoa.h>

#define MCPickerResultMode @"ResultMode"

typedef enum { RM_WEB_SHARP, RM_WEB, RM_COCOA, RM_AUTO} RESULT_MODE;

@interface MCPickerApp : NSApplication <NSApplicationDelegate>
{
	IBOutlet id resultMode;
	IBOutlet id avResultMode;
	IBOutlet id resultText;
	IBOutlet id clipboardControl;

	IBOutlet NSView* accessoryView; 
	
	RESULT_MODE autoMode;
}

-(IBAction)goHome:(id)sender;
-(IBAction)changeResultMode:(id)sender;
-(IBAction)textChanged:(id)sender;
-(IBAction)syncNow:(id)sender;
-(IBAction)clipboardCheckChanged:(id)sender;

-(void)colorChanged:(id)sender;
-(void)applyColor:(NSString*)st;

@end
