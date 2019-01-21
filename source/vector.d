module vector;

import std.math;
import std.stdio;
import std.conv;

import dsfml.system;

struct Vector{
  double x;
  double y;
  double z;

  //Constructors
  //From position
  this(double x, double y, double z){
    this.x = x;
    this.y = y;
    this.z = z;
  }
  this(double x, double y){
    this(x, y, 0);
  }
  //From angle
  this(double ang){
    Vector v = fromAngle(ang);
    this(v.x, v.y);
  }
  //Copy other vector
  this(Vector v){
    this.x = v.x;
    this.y = v.y;
  }

  //From vector2 type
  this(Vector2!float v){
    this.x = v.x;
    this.y = v.y;
    this.z = 0;
  }

  //Static methods
  static Vector fromAngle(double ang){ //2D only, radians to clockwise by
    return new Vector(0, -1).rotate(ang);
  }

  Vector rotate(double ang){ //Note that math.PI isn't exact PI and therefore sin(PI) is about 1.22e-16
    double t = x;
    x = x*cos(ang) - y*sin(ang);
    y = t*sin(ang) + y*cos(ang);
    return copy();
  }

  Vector add(double x, double y){
    return add(x, y, 0);
  }

  Vector add(double x, double y, double z){
    this.x += x;
    this.y += y;
    this.z += z;
    return copy();
  }

  Vector add(Vector v){
    this.x += v.x;
    this.y += v.y;
    this.z += v.z;
    return copy();
  }

  Vector add(Vector* v){
    this.x += v.x;
    this.y += v.y;
    this.z += v.z;
    return copy();
  }

  Vector sub(double x, double y, double z) {
    this.x -= x;
    this.y -= y;
    this.z -= z;
    return copy();
  }
  Vector sub(double x, double y) {
    return sub(x, y, 0);
  }
  Vector sub(Vector v) {
    return sub(v.x, v.y, v.z);
  }

  Vector mult(double f) {
    this.x *= f;
    this.y *= f;
    this.z *= f;
    return copy();
  }

  Vector div(double f) {
    return mult(1f/f);
  }

  double mag() {
    return sqrt(magSq());
  }

  double magSq() {
    return sq(x)+sq(y)+sq(z);
  }

  Vector limit(double f) {
    if (mag()>f) {
      setMag(f);
    }
    return copy();
  }

  Vector normalise() {
    double m = mag();
    if (m != 0f && m != 1f) {
      div(m);
    }
    return copy();
  }

  Vector setMag(double m) {
    normalise();
    mult(m);
    return copy();
  }

  Vector copy(){
    return Vector(x, y, z);
  }

  Vector2f as2f(){ //ONLY 2d
    return Vector2f(cast(float)x, cast(float)y);
  }

  float heading(){
    return atan2(x, y);
  }

  Vector lerp(Vector v, double amt){
    this.x = flerp(this.x, v.x, amt);
    this.y = flerp(this.y, v.y, amt);
    this.z = flerp(this.z, v.z, amt);
    return copy();
  }

  //Outputs
  void print(){
    writeln("["~to!string(this.x)~", "~to!string(this.y)~", "~to!string(this.z)~"]");
  }

}

double sq(double x){
  return pow(x, 2);
}

double flerp(float s, float e, float a){
  return s+(e-s)*a;
}
