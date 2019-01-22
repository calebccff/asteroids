import dsfml.graphics;
import std.stdio;

int frameCount;

void create(ref RenderWindow window, void function() setup, void function(int frameCount) draw, void function(Event e) handleEvent){
  window = new RenderWindow(VideoMode(1280, 720),//VideoMode.getFullscreenModes()[0],
   "FLOAT-asteroids",
    Window.Style.None);
  window.setFramerateLimit(60);
  setup();
  while (window.isOpen())
  {
      // check all the window's events that were triggered since the last iteration of the loop
      Event event;
      while (window.pollEvent(event)){
        handleEvent(event);
          // "close requested" event: we close the window
          if (event.type == Event.EventType.Closed){
              window.close();
            }
      }
      window.clear();
      draw(frameCount);
      ++frameCount;
      window.display();
  }
}