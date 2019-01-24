import dsfml.window.keyboard;
import dsfml.graphics;

import vector;

import std.stdio;
import std.math;
import std.random;
import std.algorithm;
import std.file;

Texture ship;
Texture tAst;

int sWidth;
int sHeight;

void objectInit(int w, int h){
    sWidth = w;
    sHeight = h;
    ship = new Texture();
    ship.loadFromFile("sprites/Ship.png");

    tAst = new Texture();
    tAst.loadFromFile("sprites/Asteroid.png");
}

class Player{
    private{
        double dirvel;
        float accelFrames;
        Vector inertia;
        Keyboard.Key[4] keys; //fd, left, right, shoot

        bool spacePressedLastFrame = false;

        struct Bullet{
            Vector pos;
            Vector vel;
            const Vector2f size = Vector2f(10, 4);
            const int speed = 10;
            int life = 72;

            this(Vector pos, double dir){
                life = sWidth/speed;
                this.pos = pos;
                vel = Vector.fromAngle(dir+PI/2).mult(speed);
            }

            void move(){
                pos.add(vel);
                pos.x = (pos.x+sWidth)%sWidth;
                pos.y = (pos.y+sHeight)%sHeight;
                --life;
            }

            Shape display(){
                auto shape = new RectangleShape(size);
                shape.position = pos.as2f();
                shape.fillColor = Color.White;
                shape.rotation(90-vel.heading()*180/PI);
                return shape;
            }
        }
    }

    public{
        Bullet[] bullets;
        Vector pos;
        double dir;
        int size = 30;
    }

    this(Keyboard.Key[4] ks){
        this.keys = ks;
        pos = Vector(300, 300);
        inertia = Vector(0, 0);
        dir = 0;
    }

    this(){
      //For enemy player
    }

    void set(int x, int y, double dir){
      pos.x = x;
      pos.y = y;
      this.dir = dir;
    }

    void newBullet(int x, int y, double dir){
      bullets ~= Bullet(Vector(x, y), dir);
    }

    void interact(){
        if(Keyboard.isKeyPressed(keys[0])){
            inertia.add(Vector.fromAngle(dir+PI/2).mult(3/(0.2+exp(0.8-0.3*accelFrames))));
            accelFrames+=0.5;
        }else{
            accelFrames = 0;
        }
        if(Keyboard.isKeyPressed(keys[1])){
            if(dirvel == 0){
                dirvel = 0.1;
            }
            dirvel += 0.001;
            if(dirvel > 0.5){
                dirvel = 0.5;
            }
            dir -= dirvel;
        }else if(Keyboard.isKeyPressed(keys[2])){
            if(dirvel == 0){
                dirvel = 0.1;
            }
            dirvel += 0.001;
            if(dirvel > 0.5){
                dirvel = 0.5;
            }
            dir += dirvel;
        }else{
            dirvel = 0;
        }
        if(Keyboard.isKeyPressed(keys[3]) && !spacePressedLastFrame){
            shoot();
            spacePressedLastFrame = true;
        }else if(!Keyboard.isKeyPressed(keys[3])){
            spacePressedLastFrame = false;
        }

        if(inertia.mag() > 10){
            inertia.setMag(10);
        }else if(inertia.mag() > 1){
            inertia.setMag(inertia.mag()-0.1).mult(0.9);
        }else {
            inertia.setMag(0);
        }

        pos.add(inertia);
        pos.x = (pos.x+sWidth)%sWidth;
        pos.y = (pos.y+sHeight)%sHeight;
        for(long i = bullets.length-1; i >= 0; i--){
            if(bullets[i].life < 1){
                bullets = remove(bullets, i);
                continue;
            }
            bullets[i].move();
        }
    }

    Shape display(){
        auto shape = new RectangleShape(Vector2f(size*1.5, size));
        shape.setTexture(ship);

        shape.fillColor(Color.White);
        shape.rotation(dir*180/PI);
        shape.position = pos.as2f();
        shape.origin = Vector2f(size*1.5/2, size/2);

        return shape;
    }

    void shoot(){
        bullets ~= Bullet(pos, dir);
        if(bullets.length > 10){
            bullets = bullets[1..bullets.length];
        }
    }
}

class Asteroid{
    Vector pos;
    Vector vel;
    int radius;
    float rot;

    this(){
        pos = Vector(uniform(0, sWidth), uniform(0, sHeight));
        vel = Vector.fromAngle(uniform(0, PI*2)).mult(uniform(0.5, 2));

        radius = uniform(40, 100);
        rot = uniform(0, 360);
    }

    this(Vector pos, Vector vel, int radius){
        this.pos = pos;
        this.vel = vel;
        this.radius = radius;
        rot = uniform(0, 360);
    }

    void move(){
        pos.add(vel);
        pos.x = (pos.x+sWidth)%sWidth;
        pos.y = (pos.y+sHeight)%sHeight;
    }

    void randomPos(){
        pos = Vector(uniform(0, sWidth), uniform(0, sHeight));
    }

    Shape display(){
        auto circle = new RectangleShape(Vector2f(radius, radius));
        circle.setTexture(tAst);
        circle.fillColor = Color.White;
        circle.position = pos.as2f()+Vector2f(radius/2, radius/2);
        circle.origin = Vector2f(radius/2, radius/2);
        circle.rotation(rot);
        return circle;
    }

    Asteroid[] hit(){
        if(radius*2/3 < 30){
            return [];
        }
        return [new Asteroid(pos, vel.rotate(PI/2), radius*2/3), new Asteroid(pos, vel.rotate(-PI/2), radius*2/3)];
    }
}
