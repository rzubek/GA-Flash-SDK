package 
{
	import flash.display.Sprite;
	import flash.events.Event;
	import gameanalytics.EventCategory;
	import gameanalytics.GameAnalytics;
	import gameanalytics.GameAnalyticsError;
	
	/**
	 * ...
	 * @author Julian Ridley Pryn
	 */
	public class Main extends Sprite 
	{
		
		public function Main():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		private function init(e:Event = null):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			
			GameAnalytics.DEBUG_MODE = true;
			GameAnalytics.RUN_IN_EDITOR_PLAY_MODE = false;
			GameAnalytics.init("d70754bf7b379a5f88f16c457057ef51", "059b6be999ac2b56f8648675a81d5cc0cf27b518","0.0","julian_ridley");
						
			try{				
				
				GameAnalytics.newEvent(EventCategory.DESIGN, { event_id:"Test;Event" } );
				
			}catch (e:GameAnalyticsError) {
				trace("GameAnalyticsError: " + e.message);				
			}
		}
		
		
	}
	
}