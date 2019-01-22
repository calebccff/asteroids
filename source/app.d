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
import core.thread;
import std.algorithm : remove;
import std.random : uniform;
import std.conv;
import std.csv;
import std.typecons; //tuples
import std.file;
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
Score score;

//Settings
const bool DEBUG=false;
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
}
struct Score{
  string name;
  int score;
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

  score = Score("sam", 0);
}

void gameInit(){
	player = new Player([Keyboard.Key.W, Keyboard.Key.A, Keyboard.Key.D, Keyboard.Key.Space]);
  asts = [];
	for(int i = 0; i < 5; i++){
		asts ~= new Asteroid();
	}
  if(!meta.solo){
    buffer = new Buffer(net.isHost, net.port);
  }
}

void text(string t, int s, double x, double y){
	Text tex = new Text(t, font, s);
	FloatRect textRect = tex.getLocalBounds();
	tex.origin = Vector2f(textRect.width/2, textRect.height/2);
	tex.position = Vector2f(x, y);
	window.draw(tex);
}

void draw(int fc){
	meta.frameCount++;
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

	if(uniform(0, 100) < 5/(1+asts.length)){
		asts ~= new Asteroid();
	}
	foreach(ref ast; asts){
		ast.move();
		window.draw(ast.display());
	}
}

void gameover(){
	text("GAMEOVER", 128, meta.width/2, meta.height*0.4);
	text("SCORE: "~to!string(score), 36, meta.width/2, meta.height*0.55);
	if(frameCount%meta.frameToggle<meta.frameToggle/2){
		text("HIGHSCORES ", 42, meta.width/2, meta.height*0.65);
	}
	if(meta.frameCount < 1){
		string s = readText("scores.csv");
    foreach (record; csvReader!(Tuple!(string, int))(s)){
      meta.hiscores ~= Score(record[0], record[1]);
    }
	}
	{
		foreach (i, score; meta.hiscores){
			text(score.name~": "~to!string(score.score), 36, meta.width/2, meta.height*0.75+meta.height*0.06*i);
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

void gameHostLoop(){
	player.interact();
  writeln("Interacted");
	for(long i = asts.length-1; i >= 0; i--){
		auto a = FloatRect(asts[i].pos.x, asts[i].pos.y, sqrt(0.6f*sq(asts[i].radius)), sqrt(0.6f*sq(asts[i].radius)));
		auto p = FloatRect(player.pos.x-player.size/2, player.pos.y-player.size/2, player.size, player.size);
		if(a.intersects(p)){
			if(meta.frameCount < 60){
				asts = remove(asts, i);
			}else{
				//scene = Scene.gameover;
				//meta.frameCount = -1;
				//asts = [];
				//return;
			}
		}
		asts[i].move();
		window.draw(asts[i].display());
		if(DEBUG){
      ahitbox.size = Vector2f(sqrt(0.6f*sq(asts[i].radius)), sqrt(0.6f*sq(asts[i].radius)));
  		ahitbox.position = Vector2f(asts[i].pos.x, asts[i].pos.y);
			window.draw(ahitbox);
    }
		foreach(ref bullet; player.bullets){
			auto b = FloatRect(bullet.pos.x, bullet.pos.y, bullet.size.x, bullet.size.x);
			if(b.intersects(a)){
				int sc = 250-50*cast(int)floor(cast(float)bullet.life/50f);
				score.score += (sc<0?50:sc);
				bullet.life = 0;
				Asteroid[] t = asts[i].hit();
				asts = remove(asts, i);
				asts ~= t;
				break;
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

	text(to!string(score), 48, meta.width*0.1, meta.height*0.1);

  if(!meta.solo){ //Networking

    if(buffer.connected){
      buffer.startPacket(Buffer.PacketType.Player); //Player data
      buffer.add(to!int(player.pos.x));
      buffer.add(to!int(player.pos.y));
      buffer.add(to!int(player.dir/PI*1000));
      buffer.flush();

      buffer.startPacket(Buffer.PacketType.Bullets);
      foreach(b; player.bullets){
        buffer.add(to!int(b.pos.x));
        buffer.add(to!int(b.pos.y));
        buffer.add(to!int(b.vel.heading()/PI*1000));
      }
      buffer.flush();

      buffer.startPacket(Buffer.PacketType.Asteroids);
      foreach(a; asts){
        buffer.add(to!int(a.pos.x));
        buffer.add(to!int(a.pos.y));
        buffer.add(to!int(a.rot/PI*1000));
      }
      buffer.flush();
    }else{
      buffer.listen();
    }
  }
}

void gameClientLoop(){
  player.interact();
  for(long i=0; i < asts.length;i++){
    window.draw(asts[i].display());
  }
  window.draw(player.display());
  foreach(ref bullet; player.bullets){
		window.draw(bullet.display());
	}

  {//Networking
    if(!buffer.connected){
      buffer.connect(net.ip, net.port); //Blocks until connection is made
    }else{
      ubyte[] recv = buffer.receive();
      ubyte type = recv[0];
      recv = recv[1..$];
      alias ci = Buffer.conv2int;
      switch(recv[0]){
        case Buffer.PacketType.Player:
          enemy.set(ci(recv[0..4]), ci(recv[4..8]), ci(recv[8..12])/1000f*PI);
          break;
        case Buffer.PacketType.Bullets:
          for(int i = 1; i < recv.length-3; i+=4){
            ubyte[4] val = recv[i..i+4];
            int x = buffer.conv2int(val);
          }
          break;
        case Buffer.PacketType.Asteroids:
          break;
        default:
          break;
      }
    }
  }
}

void handleEvent(Event event){
	if(event.type == Event.EventType.KeyPressed){
		switch(scene){
			case Scene.menu:
				if(event.key.code == Keyboard.Key.Escape){
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
  				meta.frameCount = -1;
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
				if(event.key.code == Keyboard.Key.Escape || event.key.code == Keyboard.Key.Q){
					window.close();
					return;
				}
				if(meta.frameCount > 30){
					score.score = 0;
					scene = Scene.menu;
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
