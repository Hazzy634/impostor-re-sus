package backend;

import flixel.addons.ui.FlxUIState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.FlxState;
#if mobileC
import mobile.MobileControls;
import mobile.flixel.FlxVirtualPad;
import flixel.util.FlxDestroyUtil;
#end

class MusicBeatState extends FlxUIState
{
	public static var instance:MusicBeatState;

	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	public var controls(get, never):Controls;
	private function get_controls()
	{
		return Controls.instance;
	}

	#if mobileC
	public var virtualPad:FlxVirtualPad;
	public var mobileControls:MobileControls;
	public static var mobileCMode:String;

	public function addVirtualPad(DPad:FlxDPadMode, Action:FlxActionMode)
	{
		virtualPad = new FlxVirtualPad(DPad, Action);
		virtualPad.alpha = 0.6;
		add(virtualPad);
	}

	public function removeVirtualPad()
	{
		if (virtualPad != null)
			remove(virtualPad);
	}

	public function addMobileControls(DefaultDrawTarget:Bool = true):Void
	{
		mobileControls = new MobileControls();

		var camControls = new flixel.FlxCamera();
		camControls.bgColor.alpha = 0;
		FlxG.cameras.add(camControls, DefaultDrawTarget);

		mobileControls.cameras = [camControls];
		mobileControls.visible = false;
		mobileControls.alpha = 0.6;
		add(mobileControls);
		switch (MobileControls.getMode())
        {
	  case 0: mobileCMode = 'left';
	  case 1: mobileCMode = 'right';
	  case 2: mobileCMode = 'custom';
	  case 3: mobileCMode = 'duo';
	  case 4: mobileCMode = 'hitbox';
	  case 5: mobileCMode = 'none';
         }
		// configure the current mobile control binds, without this there gonna be conflict and input issues.
		switch (MobileControls.getMode())
				{
					case 0 | 1 | 2: // RIGHT_FULL, LEFT_FULL and CUSTOM
					ClientPrefs.mobileBinds = controls.mobileBinds = [
						'note_up'		=> [UP],
						'note_left'		=> [LEFT],
						'note_down'		=> [DOWN],
						'note_right'	=> [RIGHT],
				
						'ui_up'			=> [UP], //idk if i remove these the controls in menus gonna get fucked
						'ui_left'		=> [LEFT],
						'ui_down'		=> [DOWN],
						'ui_right'		=> [RIGHT],
				
						'accept'		=> [A],
						'back'			=> [B],
						'pause'			=> [NONE],
						'reset'			=> [NONE]
					];
					case 3: // BOTH
					ClientPrefs.mobileBinds = controls.mobileBinds = [
						'note_up'		=> [UP, UP2],
						'note_left'		=> [LEFT, LEFT2],
						'note_down'		=> [DOWN, DOWN2],
						'note_right'	=> [RIGHT, RIGHT2],
				
						'ui_up'			=> [UP],
						'ui_left'		=> [LEFT],
						'ui_down'		=> [DOWN],
						'ui_right'		=> [RIGHT],
				
						'accept'		=> [A],
						'back'			=> [B],
						'pause'			=> [NONE],
						'reset'			=> [NONE]
					];
					case 4: // HITBOX
					ClientPrefs.mobileBinds = controls.mobileBinds = [
						'note_up'		=> [hitboxUP],
						'note_left'		=> [hitboxLEFT],
						'note_down'		=> [hitboxDOWN],
						'note_right'	=> [hitboxRIGHT],
				
						'ui_up'			=> [UP],
						'ui_left'		=> [LEFT],
						'ui_down'		=> [DOWN],
						'ui_right'		=> [RIGHT],
				
						'accept'		=> [A],
						'back'			=> [B],
						'pause'			=> [NONE],
						'reset'			=> [NONE]
					];
					case 5: // KEYBOARD
					//sex, idk maybe nothin'?
				}
	}

	public function removeMobileControls()
	{
		if (mobileControls != null)
			remove(mobileControls);
	}

	public function addPadCamera(DefaultDrawTarget:Bool = true):Void
	{
		if (virtualPad != null)
		{
			var camControls:FlxCamera = new FlxCamera();
			camControls.bgColor.alpha = 0;
			FlxG.cameras.add(camControls, DefaultDrawTarget);
			virtualPad.cameras = [camControls];
		}
	}
	#end

	override function destroy()
	{
		super.destroy();

		#if mobileC
		if (virtualPad != null)
		{
			virtualPad = FlxDestroyUtil.destroy(virtualPad);
			virtualPad = null;
		}

		if (mobileControls != null)
		{
			mobileControls = FlxDestroyUtil.destroy(mobileControls);
			mobileControls = null;
		}
		#end
	}

	public static var camBeat:FlxCamera;

	override function create() {
		instance = this;
		camBeat = FlxG.camera;
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		#if MODS_ALLOWED Mods.updatedOnState = false; #end

		super.create();

		if(!skip) {
			openSubState(new CustomFadeTransition(0.7, true));
		}
		FlxTransitionableState.skipNextTransOut = false;
		timePassedOnState = 0;
	}

	public static var timePassedOnState:Float = 0;
	override function update(elapsed:Float)
	{
		//everyStep();
		var oldStep:Int = curStep;
		timePassedOnState += elapsed;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep)
		{
			if(curStep > 0)
				stepHit();

			if(PlayState.SONG != null)
			{
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}

		if(FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;
		
		stagesFunc(function(stage:BaseStage) {
			stage.update(elapsed);
		});

		super.update(elapsed);
	}

	private function updateSection():Void
	{
		if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while(curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}

	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if(stepsToDo > curStep) break;
				
				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public static function switchState(nextState:FlxState = null) {
		if(nextState == null) nextState = FlxG.state;
		if(nextState == FlxG.state)
		{
			resetState();
			return;
		}

		if(FlxTransitionableState.skipNextTransIn) FlxG.switchState(nextState);
		else startTransition(nextState);
		FlxTransitionableState.skipNextTransIn = false;
	}

	public static function resetState() {
		if(FlxTransitionableState.skipNextTransIn) FlxG.resetState();
		else startTransition();
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	public static function startTransition(nextState:FlxState = null)
	{
		if(nextState == null)
			nextState = FlxG.state;

		FlxG.state.openSubState(new CustomFadeTransition(0.6, false));
		if(nextState == FlxG.state)
			CustomFadeTransition.finishCallback = function() FlxG.resetState();
		else
			CustomFadeTransition.finishCallback = function() FlxG.switchState(nextState);
	}

	public static function getState():MusicBeatState {
		return cast (FlxG.state, MusicBeatState);
	}

	public function stepHit():Void
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();
	}

	public var stages:Array<BaseStage> = [];
	public function beatHit():Void
	{
		//trace('Beat: ' + curBeat);
		stagesFunc(function(stage:BaseStage) {
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
	}

	public function sectionHit():Void
	{
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});
	}

	function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if(stage != null && stage.exists && stage.active)
				func(stage);
	}

	function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		if(PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}
}
