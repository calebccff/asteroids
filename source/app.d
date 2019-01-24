/*********
 *IMPORTS*
 *********/
//Libs
import dsfml.graphics;
import dsfml.system;
import dsfml.window;

//Standard libs
import std.stdio;
import std.math;
//import core.thread;
import std.algorithm : remove, sort;
import std.algorithm.iteration;
import std.random : uniform;
import std.conv;
import std.csv;
import std.typecons; //tuples
import std.file;
import std.array;
import std.traits; //enum members
import std.parallelism : task, taskPool;
import std.string;
//Networking
import std.socket;

//Local
import game;
import objects;
import network;

import vector;

//Window management;
RenderWindow window;

//Game objects
Player player;
Player enemy;
Asteroid[] asts;

//Settings
const bool DEBUG=false;
const ushort PACKET_LENGTH=17;
RectangleShape ahitbox;

//Meta
Scene scene;
Network net;
Font font;
Meta meta;
Buffer buffer;

//Strctures
enum Scene{
	startup,
	menu,
	gameHost,
  gameClient,
	gameover
}
struct Network{
	string ip = "192.168.43.186";
  ushort port = 1234;
	bool isHost = true;
}
struct Meta{
	int width;
	int height;
	long frameCount;
	int frameToggle = 30;
	Score[] hiscores;
  bool solo = false;
	string name = "";
	bool nameConfirm = false;
}

void setup(){
	meta.width = window.size.x;
	meta.height = window.size.y;
	objectInit(meta.width, meta.height);

	ahitbox = new RectangleShape(Vector2f(1, 1));
	ahitbox.fillColor = Color.Transparent;
	ahitbox.outlineColor = Color.Green;
	ahitbox.outlineThickness = 1;

	font = new Font();
	font.loadFromFile("fonts/Hyperspace.otf");
}

void gameInit(){
	player = new Player([Keyboard.Key.W, Keyboard.Key.A, Keyboard.Key.D, Keyboard.Key.Space]);
  asts = [];
  if(net.isHost){
  	for(int i = 0; i < 5; i++){
  		asts ~= new Asteroid();
  	}
  }
  if(!meta.solo){
    buffer = new Buffer(net.isHost, net.ip, net.port);

	}
  enemy = new Player();
	player.score.score = 0;
	enemy.score.score = 0;
	meta.frameCount = -1;
}

enum TextAlign{
  center,
  left
}

void text(string t, int s, double x, double y){
  text(t, s, x, y, TextAlign.center);
}

void text(string t, int s, double x, double y, TextAlign a){
	Text tex = new Text(t, font, s);
	FloatRect textRect = tex.getLocalBounds();
  switch(a){
    case TextAlign.center:
      tex.origin = Vector2f(textRect.width/2, textRect.height/2);
      break;
    case TextAlign.left:
    default:
      tex.origin = Vector2f(0, textRect.height/2);
      break;
  }

	tex.position = Vector2f(x, y);
	window.draw(tex);
}

void draw(int fc){
	meta.frameCount++;
	if(scene != Scene.menu && !meta.solo){
		netRecv();
  	netSend();
	}
	switch(scene){
		case Scene.menu:
			menu();
			break;
		case Scene.gameHost:
			gameHostLoop();
			break;
    case Scene.gameClient:
  		gameClientLoop();
  		break;
		case Scene.gameover:
			gameover();
			break;
		default:
			break;
	}
}

void menu(){
	text("ASTEROIDS", 96, meta.width/2, meta.height/2);
	if(frameCount%meta.frameToggle<meta.frameToggle/2){
		text("INSERT COIN TO START", 32, meta.width/2, meta.height*0.8);
	}
  text("PRESS 'H' TO HOST, 'S' FOR SOLO OR ANY KEY FOR CLIENT", 28, meta.width/2, meta.height*0.9);

	if(uniform(0, 100) < 5/(1+asts.length)){
		asts ~= new Asteroid();
	}
	foreach(ref ast; asts){
		ast.move();
		window.draw(ast.display());
	}
}

void gameover(){
	if (meta.nameConfirm) {
		text("GAMEOVER", 128, meta.width/2, meta.height*0.3);
	} else {
		string s = meta.name~(meta.frameCount%40<20?"":"|");
		text(s, 128, meta.width/2, meta.height*0.3);
	}
	text(player.score.name~": "~to!string(player.score.score), 36, meta.width/2, meta.height*0.55);
	if(!meta.solo) text(enemy.score.name~": "~to!string(enemy.score.score), 36, meta.width/2, meta.height*0.6);
	if(frameCount%meta.frameToggle<meta.frameToggle/2){
		text("HIGHSCORES ", 42, meta.width/2, meta.height*0.65);
	}
	
	{
		foreach (i, sc; meta.hiscores){
      if(i < 3)
			   text(sc.name~": "~to!string(sc.score), 36, meta.width/2, meta.height*0.75+meta.height*0.06*i);
		}
	}
}
/*
void startup(){
	writeln("#############");
	writeln("# Main Menu #");
	writeln("#############");
	writeln("1. Play");
	writeln("2. Quit");
	while(1){
		writef("> ");
		string choice = to!string(readln()[0]);
		if(choice == "1"){
			writeln("host?");
			writef("> ");
			net.isHost = readln()[0]=='y';
			if(net.isHost){
				scene = Scene.game;
				break;
			}
			writeln("Enter ip");
			writef("> ");
			net.ip = to!string(readln()[0..$-1]);
			scene = Scene.game;
			break;
		}else{
			while(1){}
		}
	}
}*/

void netRecv(){
  bool resetBullets = false;
  bool resetAsts = false;
  // for(int c=0;;c++){
  //   if(c==-1) break;
    ubyte[] r = buffer.receive();
    for(int i = 0; i < r.length; i+=PACKET_LENGTH){ //5*4
      ubyte type = r[i];
      if(type == 99 || r.length < 4) {break;} //No data
			writeln("RECV: ", r);
      ubyte[] bsl = r[i+1..i+PACKET_LENGTH]; //Slice off first byte

      //writeln("RECV: ", type, "@", bsl);
      alias ci = Buffer.conv2int;
  		switch(type){
  			case Buffer.PacketType.Player: //Last 4 bytes not used
  				enemy.set(ci(bsl[0..4]), ci(bsl[4..8]), ci(bsl[8..12])/1000f*PI);
  				break;
  			case Buffer.PacketType.Bullets:
          if(!resetBullets){
            resetBullets = true;
            enemy.bullets = [];
          }
  				enemy.newBullet(ci(bsl[0..4]), ci(bsl[4..8]), ci(bsl[8..12]));
  				break;
  			case Buffer.PacketType.Asteroids:
          if(net.isHost) break;
          if(!resetAsts){
            resetAsts = true;
            asts = [];
          }
          asts ~= new Asteroid(ci(bsl[0..4]), ci(bsl[4..8]), ci(bsl[8..12]), ci(bsl[12..16]));
  				break;
				case Buffer.PacketType.PData:
					enemy.score.name = assumeUTF(bsl[0..4]);
					enemy.score.score = ci(bsl[4..8]);
					player.score.score = ci(bsl[12..16]);
					break;
				case Buffer.PacketType.GameOver:
					scene = Scene.gameover;
					break;
  			default:
  				break;
  		}
    }
  //}
  if(!resetBullets){
    enemy.bullets = [];
  }
}

void netSend(){ //Each packets is 4 ints + 1 byte or 17 bytes
	switch(scene){
		case Scene.gameHost:
		case Scene.gameClient:
			buffer.startPacket(Buffer.PacketType.Player); //Player data
			buffer.add(to!int(player.pos.x));
			buffer.add(to!int(player.pos.y));
			buffer.add(to!int(player.dir/PI*1000));
			buffer.pad(4);
			//buffer.flush(net.ip, net.port);

			buffer.startPacket(Buffer.PacketType.Bullets);
			buffer.add(-1000);
			buffer.add(-1000);
			buffer.pad(8);
			foreach(b; player.bullets){
				buffer.startPacket(Buffer.PacketType.Bullets);
				buffer.add(to!int(b.pos.x));
				buffer.add(to!int(b.pos.y));
				buffer.add(to!int(b.vel.heading()/PI*1000));
				buffer.pad(4);
			}
			//buffer.flush(net.ip, net.port);
			if(net.isHost){
				buffer.startPacket(Buffer.PacketType.Asteroids);
				buffer.add(-1000);
				buffer.add(-1000);
				buffer.pad(8);
				foreach(a; asts){
					buffer.startPacket(Buffer.PacketType.Asteroids);
					buffer.add(to!int(a.pos.x));
					buffer.add(to!int(a.pos.y));
					buffer.add(to!int(a.rot/PI*1000));
					buffer.add(a.radius);
				}
				buffer.startPacket(Buffer.PacketType.PData);
				buffer.pad(8);
				buffer.add(enemy.score.name);
				buffer.add(enemy.score.score);
			}
		break;
		case Scene.gameover:
			if(!meta.nameConfirm){
				buffer.startPacket(Buffer.PacketType.GameOver);
				buffer.pad(PACKET_LENGTH-1);
			}else{
				buffer.startPacket(Buffer.PacketType.PData);
				buffer.add(player.score.name);
				buffer.add(player.score.score);
				buffer.pad(8);
			}
			break;
		default:
			buffer.startPacket(Buffer.PacketType.NoData);
			buffer.pad(PACKET_LENGTH-1);
			break;
	}
  buffer.flush(net.ip, net.port);
}

void gameHostLoop(){
  if(!meta.solo){ //Networking

    if(!buffer.connected){
      window.clear();
      text("Waiting for client...", 32, meta.width/2, meta.height*0.7);
    }
    //netRecv();
    //netSend();
    window.draw(enemy.display());

  	foreach(ref bullet; enemy.bullets){
  		window.draw(bullet.display());
  	}
  }

	player.interact();
  foreach(pl; [player, enemy]){
  	for(long i = asts.length-1; i >= 0&&asts.length>0; i--){
  		auto a = FloatRect(asts[i].pos.x, asts[i].pos.y, sqrt(0.6f*sq(asts[i].radius)), sqrt(0.6f*sq(asts[i].radius)));
  		auto p = FloatRect(pl.pos.x-pl.size/2, pl.pos.y-pl.size/2, pl.size, pl.size);
  		if(a.intersects(p)){
  			if(meta.frameCount < 60){
  				asts = remove(asts, i);
  			}else if(buffer.connected){ //I'm literally dead
  				scene = Scene.gameover;
  				meta.frameCount = -1;
  				asts = [];
  				return;
  			}
  		}
  		asts[i].move();
  		window.draw(asts[i].display());
  		if(DEBUG){
        ahitbox.size = Vector2f(sqrt(0.6f*sq(asts[i].radius)), sqrt(0.6f*sq(asts[i].radius)));
    		ahitbox.position = Vector2f(asts[i].pos.x, asts[i].pos.y);
  			window.draw(ahitbox);
      }
  		foreach(ref bullet; pl.bullets){
  			auto b = FloatRect(bullet.pos.x, bullet.pos.y, bullet.size.x, bullet.size.x);
  			if(b.intersects(a) && buffer.connected){
  				int sc = 250-50*cast(int)floor(cast(float)bullet.life/50f);
  				pl.score.score += (sc<0?50:sc);
  				bullet.life = 0;
  				Asteroid[] t = asts[i].hit();
  				asts = remove(asts, i);
  				asts ~= t;
  				break;
  			}
  		}

  	}
  }
	window.draw(player.display());
	foreach(ref bullet; player.bullets){
		window.draw(bullet.display());
	}
	if(uniform(0, 200) <= 30/( 10*asts.length )){
		Asteroid as = new Asteroid();
		auto a = FloatRect(as.pos.x, as.pos.y, sqrt(0.6f*sq(as.radius)), sqrt(0.6f*sq(as.radius)));
		auto p = FloatRect(player.pos.x-player.size/2, player.pos.y-player.size/2, player.size, player.size);
		while(a.intersects(p)) as.randomPos();
		asts ~= as;
	}

	if(DEBUG){
    ahitbox.size = Vector2f(player.size, player.size);
    ahitbox.position = Vector2f(player.pos.x-player.size/2, player.pos.y-player.size/2);
    window.draw(ahitbox);
  }

	text(to!string(player.score.score), 48, meta.width*0.1, meta.height*0.1);


}

void gameClientLoop(){
  if(!buffer.connected){
    window.clear();
    text("Connecting...", 32, meta.width/2, meta.height*0.7);
    //Skip first frame to let the screen redraw
  }
	
	player.interact();
  for(long i=0; i < asts.length;i++){
    window.draw(asts[i].display());
  }
  window.draw(player.display());
	window.draw(enemy.display());

	foreach(ref bullet; enemy.bullets){
		window.draw(bullet.display());
	}
	foreach(ref bullet; player.bullets){
		window.draw(bullet.display());
	}
  text(to!string(player.score.score), 48, meta.width*0.1, meta.height*0.1);
}

void handleEvent(Event event){
	if (event.type == Event.EventType.TextEntered){
		if (scene == Scene.gameover) {
			if (meta.name.length < 4 && event.text.unicode > 32) {
				meta.name ~= event.text.unicode;
			}
		}
	} else if(event.type == Event.EventType.KeyPressed){
		switch(scene){
			case Scene.menu:
				if(event.key.code == Keyboard.Key.Escape || event.key.code == Keyboard.Key.Q){
					window.close();
					return;
				}
        if(meta.frameCount > 30){
          if(event.key.code == Keyboard.Key.H){
            net.isHost = true;
      		  scene = Scene.gameHost;
          }else if(event.key.code == Keyboard.Key.S){
            meta.solo = true;
            scene = Scene.gameHost;
          }else{
            net.isHost = false;
            scene = Scene.gameClient;
          }
  				gameInit();
        }
				break;
			case Scene.gameHost: case Scene.gameClient:
				if(event.key.code == Keyboard.Key.Q){
					window.close();
					return;
				}
				break;
			case Scene.gameover:
				if (meta.nameConfirm) {
					if(event.key.code == Keyboard.Key.Escape || event.key.code == Keyboard.Key.Q){
						window.close();
						return;
					} else if(meta.frameCount > 30){
						meta.name = "";
						meta.nameConfirm = false;
						meta.solo = false;
						scene = Scene.menu;
					}
				} else {
					 if (event.key.code == Keyboard.Key.Return) {
						 if (meta.name.length > 0) {
						 	meta.nameConfirm = true;
							player.score.name = meta.name;
							string s = readText("scores.csv");
							foreach (record; csvReader!(Tuple!(string, int))(s)){
								meta.hiscores ~= Score(record[0], record[1]);
							}
							meta.hiscores ~= player.score;
							sort!((a,b)=>a.score > b.score)(meta.hiscores);
							std.file.remove("scores.csv");
							File sfile = File("scores.csv", "w");
							sfile.write(join(map!(s => s.name~","~to!string(s.score))(meta.hiscores), "\n"));
						}
					 } else if (event.key.code == Keyboard.Key.BackSpace) {
 						if (meta.name.length > 0) {
							meta.name = meta.name[0..$-1].dup;
						}
 					}
				}
				break;
			default:
				break;
		}
	}
}

void main(){
	//startup();
	scene = Scene.menu;
	game.create(window, &setup, &draw, &handleEvent); //Initialises the window, calls setup once and then calls draw
}
