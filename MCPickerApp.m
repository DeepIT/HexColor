#import "MCPickerApp.h"

#define ClipboardControlKey @"ClipboardControl"
#define AutoModeKey @"AutoMode"

@implementation MCPickerApp

-(RESULT_MODE)mode
{
	NSNumber * modeNumber = [[NSUserDefaults standardUserDefaults] valueForKey:MCPickerResultMode];
	RESULT_MODE mode = [modeNumber isKindOfClass:[NSNumber class]] ? [modeNumber intValue] : RM_AUTO;
	if (mode > RM_AUTO)
		mode = RM_WEB_SHARP;
	return mode;
}

-(id)init
{
	self = [super init];
	if (self)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:self];
	}
	return self;
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

-(void)adjustCheckedResult:(RESULT_MODE)mode
{
	NSString* comment = nil;
	switch(autoMode)
	{
		case RM_WEB:
			comment = @"Web";
			break;
		case RM_WEB_SHARP:
			comment = @"Web #";
			break;
		case RM_COCOA:
			comment = @"NSColor";
			break;
	}
	
	NSMenuItem * item;
	
	for (item in [[resultMode submenu] itemArray])
	{
		if ([item isSeparatorItem])
			continue;
		[item setState: [item tag] == mode ? NSOnState : NSOffState];
		if ([item tag] == RM_AUTO && comment)
			[item setTitle:[NSString stringWithFormat:@"Auto: %@",comment]];
	}

	for (item in [avResultMode itemArray])
	{
		if ([item isSeparatorItem])
			continue;
		if ([item tag] == mode)
			[avResultMode selectItem:item];
		if ([item tag] == RM_AUTO && comment)
			[item setTitle:[NSString stringWithFormat:@"Auto: %@",comment]];
	}
}

-(IBAction)changeResultMode:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:MCPickerResultMode];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	if ([sender tag] != RM_AUTO)
		autoMode = [sender tag];

	[self adjustCheckedResult:[sender tag]];
		
	[self colorChanged:[NSColorPanel sharedColorPanel]];
}

-(void)didFinishLaunching:(NSNotification*)aNotification
{
	[self adjustCheckedResult:[self mode]];
}

-(NSString*)internalWebColor:(NSColor*)aColor withAlpha:(BOOL)hasAlpha
{
 aColor = [aColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
 return [[NSString stringWithFormat:@"%02X%02X%02X",
									(unsigned)([aColor redComponent]*255.0+0.49),
									(unsigned)([aColor greenComponent]*255.0+0.49),
									(unsigned)([aColor blueComponent]*255.0+0.49)]
									stringByAppendingFormat: (hasAlpha ? @"%02X" : @""), (unsigned)([aColor alphaComponent]*255.0+0.49)];
}

-(NSString*)webColor:(NSColor*)aColor withSharp:(BOOL)sharp withAlpha:(BOOL)hasAlpha
{
 return [NSString stringWithFormat:(sharp?@"#%@":@"%@"),[self internalWebColor:aColor withAlpha:hasAlpha]];
}

-(NSString*)cocoaColor:(NSColor*)aColor
{
 aColor = [aColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	return [NSString stringWithFormat:@"[NSColor colorWithCalibratedRed:0x%02X/255.0 green:0x%02X/255.0 blue:0x%02X/255.0 alpha:0x%02X/255.0]/* %@ */",
									(unsigned)([aColor redComponent]*255.0+0.49),
									(unsigned)([aColor greenComponent]*255.0+0.49),
									(unsigned)([aColor blueComponent]*255.0+0.49),
									(unsigned)([aColor alphaComponent]*255.0+0.49),
	[self webColor:aColor withSharp:NO withAlpha:YES]
	];
}

-(void)returnColor:(NSColor*)color inMode:(RESULT_MODE)mode
{
	NSPasteboard * gPB = [NSPasteboard generalPasteboard];
	NSString* colorString = nil;
	
	switch(mode)
	{
		case RM_WEB_SHARP:
			colorString = [self webColor:color withSharp:YES withAlpha:NO];
			if ([clipboardControl state] == NSOnState)
			{
				[gPB declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
				[gPB setString:colorString forType:NSStringPboardType];
			}
			break;
		case RM_WEB:
			colorString = [self webColor:color withSharp:NO withAlpha:NO];
			if ([clipboardControl state] == NSOnState)
			{
				[gPB declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
				[gPB setString:colorString forType:NSStringPboardType];
			}
			break;
		case RM_COCOA:
			colorString = [self cocoaColor:color];
			if ([clipboardControl state] == NSOnState)
			{
				[gPB declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
				[gPB setString:colorString forType:NSStringPboardType];
			}
			break;
		case RM_AUTO:
			[self adjustCheckedResult:RM_AUTO];
			return [self returnColor:color inMode:autoMode];
			break;
	}	
	
#ifdef DEBUG
	NSLog(@"%s: %@",__PRETTY_FUNCTION__,colorString);
#endif
	if (colorString)
	{
		[resultText setStringValue:colorString];
		if (![clipboardControl state])
		{
			[resultText selectText:self];
			[[NSColorPanel sharedColorPanel] makeFirstResponder:resultText];
		}
	}
}

-(void)colorChanged:(NSColorPanel*)sender
{
	[self returnColor:[sender color] inMode:[self mode]];
}

int dehex4(char ch)
{
	if (ch >= '0' && ch <= '9')
		return (ch - '0');
	if (ch >= 'a' && ch <= 'f')
		return 10 + (ch - 'a');
	if (ch >= 'A' && ch <= 'F')
		return 10 + (ch - 'A');
	return -1;
}

-(void)checkPasteboard:(NSTimer*)timer
{
	if (!timer || [clipboardControl state] == NSOnState)
	{
		NSPasteboard * pb = [NSPasteboard generalPasteboard];
		NSString * st = [pb stringForType:NSStringPboardType];
		[self applyColor:st];
	}
}

-(IBAction)clipboardCheckChanged:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender state] forKey:ClipboardControlKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(IBAction)syncNow:(id)sender
{
	[self checkPasteboard:nil];
}

-(IBAction)textChanged:(id)sender
{
	[self applyColor:[sender stringValue]];
	[self colorChanged:[NSColorPanel sharedColorPanel]];
	if (![clipboardControl state])
	{
		[resultText selectText:self];
		[[NSColorPanel sharedColorPanel] makeFirstResponder:sender];
	}
}

-(void)applyColor:(NSString*)st
{
	if (st)
	{
		RESULT_MODE prevAM = autoMode;
		
		// check st for string
		autoMode = RM_WEB;
		if ([st rangeOfString:@"NSColor"].location != NSNotFound)
			autoMode = RM_COCOA;
		NSRange range;
		if ((range = [st rangeOfString:@"/*"]).location != NSNotFound && (range.location + range.length) < [st length])
		{
			st = [st substringFromIndex:range.location + range.length];
			if ((range = [st rangeOfString:@"*/"]).location != NSNotFound)
				st = [st substringToIndex:range.location];				
		}
		
		// leading whitespace
		while ([st length] && [[st substringToIndex:1] rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound)
			st = [st substringFromIndex:1];
		
		range = [st rangeOfString:@"#"];
		if (range.location == 0)
		{
			st = [st substringFromIndex:range.location + 1];
			if (autoMode == RM_WEB)
				autoMode = RM_WEB_SHARP;
		}
		
		// terminating whitespace
		while ([st length] && 
									([[st substringFromIndex:[st length] - 1] rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound
										||
										[[st substringFromIndex:[st length] - 1] isEqualToString:@"\n"]
										||
										[[st substringFromIndex:[st length] - 1] isEqualToString:@"\r"]))
			st = [st substringToIndex:[st length] - 1];
		
		range = [st rangeOfString:@";"];
		if (range.location == [st length] - 1)
			st = [st substringToIndex:range.location];
		
		if ([st length] == 6 || [st length] == 8)
		{
			const char* su8 = [st UTF8String];
			if (su8)
			{
				unsigned r, g, b, a;
				unsigned i;
				int cur;
				r = g = b = i = 0;
				while (su8[i])
				{
					cur = dehex4(su8[i]);
					if (cur < 0)
						break;
					switch (i)
					{
						case 0:
							r = cur;
							break;
						case 1:
							r *= 0x10;
							r += cur;
							break;
							
						case 2:
							g = cur;
							break;
						case 3:
							g *= 0x10;
							g += cur;
							break;
							
						case 4:
							b = cur;
							break;
						case 5:
							b *= 0x10;
							b += cur;
							break;

						case 6:
							a = cur;
							break;
						case 7:
							a *= 0x10;
							a += cur;
							break;
					}
					i++;
				}
				
				if (i == 6)
				{
					NSColorPanel * cp = [NSColorPanel sharedColorPanel];
					if (prevAM != autoMode || [st caseInsensitiveCompare:[self internalWebColor:[cp color] withAlpha:NO]] != NSOrderedSame)
						[cp setColor:[NSColor colorWithCalibratedRed:(float)r/255.0 green:(float)g/255.0 blue:(float)b/255.0 alpha:1.0]];
				}

				if (i == 8)
				{
					NSColorPanel * cp = [NSColorPanel sharedColorPanel];
					if (prevAM != autoMode || [st caseInsensitiveCompare:[self internalWebColor:[cp color] withAlpha:YES]] != NSOrderedSame)
						[cp setColor:[NSColor colorWithCalibratedRed:(float)r/255.0 green:(float)g/255.0 blue:(float)b/255.0 alpha:(float)a/255.0]];
				}
				
				if (prevAM != autoMode)
				{
					[self adjustCheckedResult:[self mode]];
					[self colorChanged:[NSColorPanel sharedColorPanel]];
				}

			}
		}
		
	}
}

-(void)colorPanelClosed:(id)unused
{
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DontQuitOnPanelClose"])
		[NSApp terminate:self];
}

-(void)appTerminate:(NSNotification*)nt
{
	NSUserDefaults * prefs = [NSUserDefaults standardUserDefaults];
	
	[prefs setInteger:autoMode forKey:AutoModeKey];
}

-(void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appTerminate:) name:NSApplicationWillTerminateNotification object:NSApp];
	
	autoMode = [[NSUserDefaults standardUserDefaults] integerForKey:AutoModeKey];
		
	id obj = [[NSUserDefaults standardUserDefaults] objectForKey:ClipboardControlKey];
	[clipboardControl setState:!obj || [obj boolValue]];
	
	if (([[[[NSBundle mainBundle] infoDictionary] objectForKey:@"LSUIElement"] boolValue]
					||
					[[[[NSBundle mainBundle] infoDictionary] objectForKey:@"LSBackgroundOnly"] boolValue])
					&& [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowMenu"])
	{
		ProcessSerialNumber psn = { 0, kCurrentProcess };
		TransformProcessType(& psn, kProcessTransformToForegroundApplication);
		[NSApp requestUserAttention:NSInformationalRequest];
	}

	
	[self setDelegate:self];
	NSColorPanel * cp = [NSColorPanel sharedColorPanel];
	
	[cp setTitle:@"HexColor"];
	[cp setAccessoryView:accessoryView];
	[cp setShowsAlpha:YES];
	
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DontPreventActivation"])
	{
		SInt32 resp = 0;
		if (Gestalt(gestaltSystemVersion,&resp) >= 0 && resp >= 0x1060)
			[cp setStyleMask:[cp styleMask] | NSNonactivatingPanelMask];
	}
	
	[cp setTarget:self];
	[cp setAction:@selector(colorChanged:)];
	[cp makeKeyAndOrderFront:self];
	[cp setHidesOnDeactivate:NO];
	[cp setBecomesKeyOnlyIfNeeded:YES];
	
	NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkPasteboard:) userInfo:nil repeats:YES];
	
	if ([clipboardControl state])
		[self checkPasteboard:timer];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorPanelClosed:) name:NSWindowWillCloseNotification object:cp];
	
	[self colorChanged:cp];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication 
                    hasVisibleWindows:(BOOL)flag
{
 [[NSColorPanel sharedColorPanel] makeKeyAndOrderFront:self];
	if ([clipboardControl state] == NSOnState)
		[self checkPasteboard:nil];
 return YES; 
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication
{
 [[NSColorPanel sharedColorPanel] makeKeyAndOrderFront:self];
	
	if ([clipboardControl state] == NSOnState)
		[self checkPasteboard:nil];
	
 return YES; 
}


-(IBAction)goHome:(id)sender
{
 [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://deepitpro.com"]];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
 [[NSColorPanel sharedColorPanel] makeKeyAndOrderFront:self];
	if ([clipboardControl state] == NSOnState)
		[self checkPasteboard:nil];
}

@end
