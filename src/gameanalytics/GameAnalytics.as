package gameanalytics 
{
	import com.adobe.crypto.MD5;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	
	/**
	 * ...
	 * @author Julian Ridley Pryn
	 */
	public class GameAnalytics 
	{
		
		private static const REQUIRED_FIELDS_USER:Array = ["user_id", "session_id", "build"];
		private static const REQUIRED_FIELDS_DESIGN:Array = ["user_id", "session_id", "build","event_id"];
		private static const REQUIRED_FIELDS_BUSINESS:Array = ["user_id", "session_id", "build","event_id","amount","currency"];
		private static const REQUIRED_FIELDS_QUALITY:Array = ["user_id", "session_id", "build", "event_id"];
		
		
		//public static const URL:String = "http://logging.gameanalytics.com";
		public static const URL:String = "http://api.gameanalytics.com";		
		public static const PORT:int = 80;
		
		/**
		 * The version of the REST-API, currently should be always set to “1”.
		 */
		public static const API_VERSION:String = "1";
		
		/**
		 * Setting DEBUG_MODE to true will cause the Game Analytics wrapper to print additional debug information, 
		 * such as the status of each submit to the server.
		 */
		public static var DEBUG_MODE:Boolean = false;

		/**
		 * When RUN_IN_EDITOR_PLAY_MODE is set to true the Game Analytics wrapper will not submit data 
		 * to the server while playing the game in the editor.
		 */
		public static var RUN_IN_EDITOR_PLAY_MODE:Boolean = false;
		
		private static var public_key:String;
		private static var private_key:String;
		private static var build:String;
		private static var user_id:String;
		private static var session_id:String;
		
		private static var initialized:Boolean = false;
		private static var event_que:Vector.<Array> = new Vector.<Array>();
		
		/**
		 * When a new game is added to your Game Analytics account, you will get a public key and a private key 
		 * which are unique for that game.
		 * 
		 * @param public_key:String - The public key is used directly in the URL for identifying the game.
		 * @param private_key:String - The private key is used for event authentication.
		 * @param build:String - Describes the current version of the game being played.
		 * @param user_id:String - A unique ID representing the user playing your game. 
		 * @param session_id:String A unique ID representing the current play session. If not used, a unique session-id is generated. 
		 */		
		public static function init(public_key:String, private_key:String, build:String, user_id:String, session_id:String = null):void {
			GameAnalytics.public_key = public_key;
			GameAnalytics.private_key = private_key;
			GameAnalytics.build = build;
			GameAnalytics.user_id = user_id;
			GameAnalytics.session_id = session_id != null? session_id: new Date().getTime() + "x" + ((Math.random() * 1000000) >> 0);
			
			if (GameAnalytics.public_key == null || GameAnalytics.public_key.length == 0) throw new GameAnalyticsError("'public key' cannot be empty or null.");
			if (GameAnalytics.private_key == null || GameAnalytics.private_key.length == 0) throw new GameAnalyticsError("'private key' cannot be empty or null.");
			if (GameAnalytics.build == null || GameAnalytics.build.length == 0) throw new GameAnalyticsError("'build' cannot be empty or null.");
			if (GameAnalytics.user_id == null || GameAnalytics.user_id.length == 0) throw new GameAnalyticsError("'user_id' cannot be empty or null.");
			if (GameAnalytics.session_id == null || GameAnalytics.session_id.length == 0) throw new GameAnalyticsError("'session_id' cannot be empty or null.");
			
			initialized = true;
			emptyEventQue();
		}
		
		/**
		 * Send a new event to Game Analytics.
		 * 
		 * @param category:String - the category of the event. Either user, design, business or quality
		 * @param ...events - Any number of events to send.
		 */
		public static function newEvent(category:String, ...events):void
		{
			if (!initialized) {
				addToEventQue([category].concat(events));
				return;
			}

			if(category != EventCategory.USER && category != EventCategory.DESIGN && category != EventCategory.BUSINESS && category != EventCategory.QUALITY) throw new GameAnalyticsError("Event category type '" + category + "' not recognized. Valid types are: " + [EventCategory.USER,EventCategory.DESIGN,EventCategory.BUSINESS,EventCategory.QUALITY]);
			if (events.length == 0) events = [{}];
			
			var req_fields:Array = getRequiredFields(category);
			for (var h:int = 0; h < events.length; h++) {
				
				var event:Object = events[h];
				
				if (event.hasOwnProperty("build")) throw new GameAnalyticsError("Property 'build' is found on the event, but the name is reserved for Build name, which is set at init.");
				if (event.hasOwnProperty("session_id")) throw new GameAnalyticsError("Property 'session_id' is found on the event, but the name is reserved for Session Id, which is set at init.");
				if (event.hasOwnProperty("user_id")) throw new GameAnalyticsError("Property 'user_id' is found on the event, but the name is reserved for User Id, which is set at init.");
				
				event.build = build;
				event.session_id = session_id;
				event.user_id = user_id;				
				
				for (var i:int = 0; i < req_fields.length; i++) {
					if (!event.hasOwnProperty(req_fields[i])) {
						throw new GameAnalyticsError("Property '" + req_fields[i] + "' is required but not found on event with category type '" + category + "'.");
					}
				}
				
				for (var prop:String in event) 
				{
					var type:String = (typeof event[prop]);
					if ( type != "string" && type != "number" && type != "boolean"){						
						event[prop] = event[prop].toString();
					}
				}
				
				
				
			}

			
			var request:URLRequest = new URLRequest(URL + "/" + API_VERSION + "/" + public_key + "/" + category);
			var event_json:String;
			try{
				event_json = JSON.stringify(events);
			}catch (e:Error) {
				throw new GameAnalyticsError("There was an error encoding the event as a JSON object. Error: " + e.message);
			}
						
			var authHash :String = MD5.hash(event_json+private_key);
			request.data = event_json;
			request.method = URLRequestMethod.POST;
			request.requestHeaders.push(new URLRequestHeader("Authorization", authHash));
		
			var requestor:URLLoader = new URLLoader(); 
			requestor.addEventListener( Event.COMPLETE, httpRequestComplete ); 
			requestor.addEventListener( IOErrorEvent.IO_ERROR, httpRequestIOError ); 
			requestor.addEventListener( SecurityErrorEvent.SECURITY_ERROR, httpRequestSecurityError ); 

			if (DEBUG_MODE) {
				log("----");
				log("Sending Game Analytics event:" + (RUN_IN_EDITOR_PLAY_MODE? " (Running in EDITOR PLAY MODE. Not Sending event)": ""));
				log("\tUrl: " + request.url);
				log("\tHeader: " + authHash);
				log("\tData: " + request.data);
				log("----");
			}
			
			if(!RUN_IN_EDITOR_PLAY_MODE) requestor.load( request ); 
		} 
		
		private static function httpRequestComplete( event:Event ):void 
		{ 
			log("Game Analytics Request Complete: " + event.target.data );
		} 
		 
		private static function httpRequestIOError( error:IOErrorEvent ):void{ 
			log("There was an error with the Game Analytics Server. " + error.text );
		}
		
		private static function httpRequestSecurityError( error:SecurityErrorEvent ):void{ 
			log("There was an error with the Game Analytics Server. " + error.text );
		}
		
		private static function addToEventQue(arg:Array):void
		{
			event_que.push(arg);
		}
		
		private static function emptyEventQue():void
		{
			for (var i:int = 0; i < event_que.length; i++) {
				newEvent.apply(null, event_que[i]);
			}
		}
		
		/**
		 * Returns an Array of string, which represents the required values of a event of the given category.
		 */
		private static function getRequiredFields(category:String):Array
		{
			switch(category) {
				case EventCategory.USER:
					return REQUIRED_FIELDS_USER;
				break;
				case EventCategory.DESIGN:
					return REQUIRED_FIELDS_DESIGN;
				break;
				case EventCategory.BUSINESS:
					return REQUIRED_FIELDS_BUSINESS;
				break;
				case EventCategory.QUALITY:
					return REQUIRED_FIELDS_QUALITY;
				break;
				default:
					throw new GameAnalyticsError("No such category: " + category);
					return [];
				break;
			}
		}
		
		public static function log(...args):void
		{
			if (DEBUG_MODE) trace(args);
		}

	}

}