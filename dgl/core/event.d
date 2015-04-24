/*
Copyright (c) 2014-2015 Timur Gafarov 

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dgl.core.event;

private
{
    import std.stdio;
    import std.ascii;
    import derelict.sdl.sdl;
    import dlib.core.memory;
}

enum EventType
{
    KeyDown,
    KeyUp,
    TextInput,
    MouseMotion,
    MouseButtonDown,
    MouseButtonUp,
    JoystickButtonDown,
    JoystickButtonUp,
    JoystickAxisMotion,
    Resize,
    FocusLoss,
    FocusGain,
    Quit,
    UserEvent
}

struct Event
{
    EventType type;
    int key;
    dchar unicode;
    int button;
    int joystickButton;
    int joystickAxis;
    int joystickAxisValue;
    int width;
    int height;
    int userCode;
}

class EventManager
{
    enum maxNumEvents = 50;
    Event[maxNumEvents] eventStack;
    uint numEvents;
    
    bool running = true;
    
    bool keyPressed[512] = false;
    bool mouseButtonPressed[255] = false;
    int mouseX = 0;
    int mouseY = 0;
    
    double deltaTime = 0.0;
    double averageDelta = 0.0;
    uint deltaTimeMs = 0;
    int fps = 0;
    
    uint videoWidth;
    uint videoHeight;
    
    uint windowWidth;
    uint windowHeight;
    bool windowFocused = true;
    
    this(uint winWidth, uint winHeight)
    {       
        windowWidth = winWidth;
        windowHeight = winHeight;

        auto videoInfo = SDL_GetVideoInfo();
        videoWidth = videoInfo.current_w;
        videoHeight = videoInfo.current_h;
    }
    
    void addEvent(Event e)
    {
        if (numEvents < maxNumEvents)
        {
            eventStack[numEvents] = e;
            numEvents++;
        }
        else
            writeln("Warning: event stack overflow");
    }
    
    void generateUserEvent(int code)
    {
        Event e = Event(EventType.UserEvent);
        e.userCode = code;
        addEvent(e);
    }
    
    void update()
    {
        numEvents = 0;
        updateTimer();
        
        if (SDL_WasInit(SDL_INIT_JOYSTICK))
            SDL_JoystickUpdate();

        SDL_Event event;

        while(SDL_PollEvent(&event))
        {
            Event e;
            switch (event.type)
            {
                case SDL_KEYDOWN:                        
                    if ((event.key.keysym.unicode & 0xFF80) == 0)
                    {         
                        auto asciiChar = event.key.keysym.unicode & 0x7F;
                        if (isPrintable(asciiChar))
                        {
                            e = Event(EventType.TextInput);
                            e.unicode = asciiChar;
                            addEvent(e);
                        }
                    }
                    else
                    {
                        e = Event(EventType.TextInput);
                        e.unicode = event.key.keysym.unicode;
                        addEvent(e);
                    }
                    
                    keyPressed[event.key.keysym.sym] = true;
                    e = Event(EventType.KeyDown);
                    e.key = event.key.keysym.sym;
                    addEvent(e);
                    break;
                    
                case SDL_KEYUP:
                    keyPressed[event.key.keysym.sym] = false;
                    e = Event(EventType.KeyUp);
                    e.key = event.key.keysym.sym;
                    addEvent(e);
                    break;
                    
                case SDL_MOUSEMOTION:
                    mouseX = event.motion.x;
                    mouseY = windowHeight - event.motion.y;
                    break;
                    
                case SDL_MOUSEBUTTONDOWN:
                    mouseButtonPressed[event.button.button] = true;
                    e = Event(EventType.MouseButtonDown);
                    e.button = event.button.button;
                    addEvent(e);                    
                    break;
                    
                case SDL_MOUSEBUTTONUP:
                    mouseButtonPressed[event.button.button] = false;
                    e = Event(EventType.MouseButtonUp);
                    e.button = event.button.button;
                    addEvent(e);                    
                    break;
                    
                case SDL_JOYBUTTONDOWN:
                    // TODO: add state modification
                    e = Event(EventType.JoystickButtonDown);
                    e.button = event.jbutton.button+1;
                    addEvent(e);
                    break;
                    
                case SDL_JOYBUTTONUP:
                    // TODO: add state modification
                    e = Event(EventType.JoystickButtonUp);
                    e.button = event.jbutton.button+1;
                    addEvent(e);
                    break;
                    
                case SDL_JOYAXISMOTION:
                    // TODO: add state modification
                    e = Event(EventType.JoystickAxisMotion);
                    e.joystickAxis = event.jaxis.axis;
                    e.joystickAxis = event.jaxis.value;
                    addEvent(e);
                    break;
                    
                case SDL_VIDEORESIZE:
                    writefln("Window resized to %s : %s", event.resize.w, event.resize.h);
                    windowWidth = event.resize.w;
                    windowHeight = event.resize.h;
                    //writefln("Window resized to %s : %s", windowWidth, windowHeight);
                    e = Event(EventType.Resize);
                    e.width = windowWidth;
                    e.height = windowHeight;
                    addEvent(e);
                    break;
                    
                case SDL_ACTIVEEVENT:
                    if (event.active.state & SDL_APPACTIVE)
                    {
                        if (event.active.gain == 0)
                        {
                            writeln("Deactivated");
                            windowFocused = false;
                            e = Event(EventType.FocusLoss);
                        }
                        else
                        {
                            writeln("Activated");
                            windowFocused = true;
                            e = Event(EventType.FocusGain);
                        }
                    }
                    else if (event.active.state & SDL_APPINPUTFOCUS)
                    {
                        if (event.active.gain == 0)
                        {
                            writeln("Lost focus");
                            windowFocused = false;
                            e = Event(EventType.FocusLoss);
                        }
                        else
                        {
                            writeln("Gained focus");
                            windowFocused = true;
                            e = Event(EventType.FocusGain);
                        }
                    }
                    addEvent(e);
                    break;
                    
                case SDL_QUIT:
                    running = false;
                    e = Event(EventType.Quit);
                    addEvent(e);
                    break;
                    
                default:
                    break;
            }
        }
    }
    
    void updateTimer()
    {
        static int currentTime;
        static int lastTime;

        static int FPSTickCounter;
        static int FPSCounter = 0;

        currentTime = SDL_GetTicks();
        auto elapsedTime = currentTime - lastTime;
        lastTime = currentTime;
        deltaTimeMs = elapsedTime;
        deltaTime = cast(double)(elapsedTime) * 0.001;

        FPSTickCounter += elapsedTime;
        FPSCounter++;
        if (FPSTickCounter >= 1000) // 1 sec interval
        {
            fps = FPSCounter;
            FPSCounter = 0;
            FPSTickCounter = 0;
            averageDelta = 1.0 / cast(double)(fps);
	}
    }

    void setMouse(int x, int y)
    {
        SDL_WarpMouse(cast(ushort)x, cast(ushort)(windowHeight - y));
        mouseX = x;
        mouseY = y;
    }

    void setMouseToCenter()
    {
        int x = windowWidth / 2;
        int y = windowHeight / 2;
        SDL_WarpMouse(cast(ushort)x, cast(ushort)(windowHeight - y));
        mouseX = x;
        mouseY = y;
    }

    void showCursor(bool mode)
    {
        SDL_ShowCursor(mode);
    }
}

abstract class EventListener: ManuallyAllocatable
{
    EventManager eventManager;
    bool enabled = true;
    
    this(EventManager emngr)
    {
        eventManager = emngr;
    }
    
    protected void generateUserEvent(int code)
    {
        eventManager.generateUserEvent(code);
    }
    
    void processEvents()
    {
        if (!enabled)
            return;
    
        for (uint i = 0; i < eventManager.numEvents; i++)
        {
            Event* e = &eventManager.eventStack[i];
            switch(e.type)
            {
                case EventType.KeyDown:
                    onKeyDown(e.key);
                    break;
                case EventType.KeyUp:
                    onKeyUp(e.key);
                    break;
                case EventType.TextInput:
                    onTextInput(e.unicode);
                    break;
                case EventType.MouseButtonDown:
                    onMouseButtonDown(e.button);
                    break;
                case EventType.MouseButtonUp:
                    onMouseButtonUp(e.button);
                    break;
                case EventType.JoystickButtonDown:
                    onJoystickButtonDown(e.joystickButton);
                    break;
                case EventType.JoystickButtonUp:
                    onJoystickButtonDown(e.joystickButton);
                    break;
                case EventType.JoystickAxisMotion:
                    onJoystickAxisMotion(e.joystickAxis, e.joystickAxisValue);
                    break;
                case EventType.Resize:
                    onResize(e.width, e.height);
                    break;
                case EventType.FocusLoss:
                    onFocusLoss();
                    break;
                case EventType.FocusGain:
                    onFocusGain();
                    break;
                case EventType.Quit:
                    onQuit();
                    break;
                case EventType.UserEvent:
                    onUserEvent(e.userCode);
                    break;
                default:
                    break;
            }
        }
    }

    void onKeyDown(int key) {}
    void onKeyUp(int key) {}
    void onTextInput(dchar code) {}
    void onMouseButtonDown(int button) {}
    void onMouseButtonUp(int button) {}
    void onJoystickButtonDown(int button) {}
    void onJoystickButtonUp(int button) {}
    void onJoystickAxisMotion(int axis, int value) {}
    void onResize(int width, int height) {}
    void onFocusLoss() {}
    void onFocusGain() {}
    void onQuit() {}
    void onUserEvent(int code) {}
    
    mixin FreeImpl;
    mixin ManualModeImpl;
}

/*
 * Causes GC allocation
 */
import std.conv;

class TextListener: EventListener
{
    dchar[100] arr;
    uint pos = 0;

    this(EventManager emngr)
    {
        super(emngr);
    }
    
    override void onTextInput(dchar code)
    {
        if (pos < 100)
        {
            arr[pos] = code;
            pos++;
        }
    }
    
    override void onKeyDown(int key)
    {
        if (key == SDLK_BACKSPACE)
            back();
    }
    
    void reset()
    {
        arr[] = 0;
        pos = 0;
    }
    
    void back()
    {
        if (pos > 0)
            pos--;
    }
    
    override string toString()
    {
        return to!string(arr[0..pos]);
    }
    
    mixin FreeImpl;
}