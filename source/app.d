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
Asteroid[] asts;
int score = 0;

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
	startup=-1,
	menu=0,
	game=1,
	pause=2,
	gameover=3
}
struct Network{
	string ip = "127.0.0.1";
	bool isHost = true;
}
struct Meta{
	int width;
	int height;
	long frameCount;
	int frameToggle = 30;
	bool startGame = false;
	string hiscores;
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

	buffer = new Buffer(true, 2525);
}

void gameInit(){
	player = new Player([Keyboard.Key.W, Keyboard.Key.A, Keyboard.Key.D, Keyboard.Key.Space]);
	for(int i = 0; i < 5; i++){
		asts ~= new Asteroid();
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
	buffer.listen();
	switch(scene){
		case Scene.menu:
			menu();
			break;
		case Scene.game:
			gameLoop();
			break;
		case Scene.pause:
			paused();
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

	if(meta.startGame){
		asts = [];
		for(int i = 0; i < 5; i++){
			asts ~= new Asteroid();
		}
		scene = Scene.game;
	}
}

void paused(){
	window.draw(player.display());
	foreach(ref ast; asts){
		window.draw(ast.display());
	}

	text("PAUSED, PRESS ESC TO CONTINUE OR Q TO QUIT", 32, meta.width/2, meta.height*0.1);
}

void gameover(){
	text("GAMEOVER", 128, meta.width/2, meta.height*0.4);
	text("SCORE: "~to!string(score), 36, meta.width/2, meta.height*0.55);
	if(frameCount%meta.frameToggle<meta.frameToggle/2){
		text("HIGHSCORES ", 42, meta.width/2, meta.height*0.65);
	}
	if(meta.frameCount < 1){
		meta.hiscores = readText("scores.csv");
	}
	{
		int hi = 0;
		int i = 0;
		foreach (record; csvReader!(Tuple!(string, int))(meta.hiscores))
		{
			text(record[0]~": "~to!string(record[1]), 36, meta.width/2, meta.height*0.75+meta.height*0.06*i);
			if(record[1] > hi) hi = record[1];
			i++;
		}
	}
}

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
}

void gameLoop(){
	player.interact();
	for(long i = asts.length-1; i >= 0; i--){
		auto a = FloatRect(asts[i].pos.x, asts[i].pos.y, sqrt(0.6f*sq(asts[i].radius)), sqrt(0.6f*sq(asts[i].radius)));
		auto p = FloatRect(player.pos.x-player.size/2, player.pos.y-player.size/2, player.size, player.size);
		if(a.intersects(p)){
			if(meta.frameCount < 60){
				asts = remove(asts, i);
			}else{
				writeln("#############");
				writeln("# GAME OVER #");
				writeln("#############");
				//window.close();
				scene = Scene.gameover;
				meta.frameCount = -1;
				meta.startGame = false;
				asts = [];
				return;
			}
		}
		asts[i].move();
		window.draw(asts[i].display());
		ahitbox.size = Vector2f(sqrt(0.6f*sq(asts[i].radius)), sqrt(0.6f*sq(asts[i].radius)));
		ahitbox.position = Vector2f(asts[i].pos.x, asts[i].pos.y);
		if(DEBUG)
			window.draw(ahitbox);
		foreach(ref bullet; player.bullets){
			auto b = FloatRect(bullet.pos.x, bullet.pos.y, bullet.size.x, bullet.size.x);
			if(b.intersects(a)){
				int sc = 250-50*cast(int)floor(cast(float)bullet.life/50f);
				score += (sc<0?50:sc);
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
	if(uniform(0, 200) <= 30/(10*asts.length)){
		// Asteroid as = new Asteroid();
		// auto a = FloatRect(as.pos.x, as.pos.y, sqrt(0.6f*sq(as.radius)), sqrt(0.6f*sq(as.radius)));
		// auto p = FloatRect(player.pos.x-player.size/2, player.pos.y-player.size/2, player.size, player.size);
		// while(a.intersects(p)) a.randomPos();
		asts ~= new Asteroid();
	}
	ahitbox.size = Vector2f(player.size, player.size);
	ahitbox.position = Vector2f(player.pos.x-player.size/2, player.pos.y-player.size/2);
	if(DEBUG)
		window.draw(ahitbox);
	text(to!string(score), 48, meta.width*0.1, meta.height*0.1);
}

void handleEvent(Event event){
	if(event.type == Event.EventType.KeyPressed){
		switch(scene){
			case Scene.menu:
				if(event.key.code == Keyboard.Key.Escape){
					window.close();
					return;
				}
				meta.frameCount = -1;
				meta.startGame = true;
				gameInit();
				break;
			case Scene.game:
				if(event.key.code == Keyboard.Key.Escape){
					scene = Scene.pause;
				}else if(event.key.code == Keyboard.Key.Q){
					window.close();
					return;
				}
				break;
			case Scene.pause:
				if(event.key.code == Keyboard.Key.Escape){
					scene = Scene.game;
				}else if(event.key.code == Keyboard.Key.Q){
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
					score = 0;
					scene = Scene.menu;
				}
				break;
			default:
				break;
		}
	}
}

void main(){
	//menu();
	scene = Scene.menu;
	game.create(window, &setup, &draw, &handleEvent); //Initialises the window, calls setup once and then calls draw
}
