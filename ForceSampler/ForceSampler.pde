/**
 **********************************************************************************************************************
 * @file       sceneampler.pde
 * @author     Sean Bocirnea, adapted from starter code by  Steve Ding, Colin Gallacher
 * @version    V1.0.0
 * @date       02-February-2024
 * @brief      Force Feedback via normal mapping
 **********************************************************************************************************************
 * @attention
 *
 *
 **********************************************************************************************************************
 */

import processing.serial.*;
import static java.util.concurrent.TimeUnit.*;
import java.util.concurrent.*;

private final ScheduledExecutorService scheduler      = Executors.newScheduledThreadPool(1);

Board             haplyBoard;
Device            widgetOne;
Mechanisms        pantograph;

byte              widgetOneID                         = 5;
int               CW                                  = 0;
int               CCW                                 = 1;
boolean           renderingForce                      = false;

long              baseFrameRate                       = 170;

/* Screen and world setup parameters */
float             pixelsPerMeter                      = 4000.0;
float             radsPerDegree                       = 0.01745;
float             dt                                  = 1/1000.0;

/* pantagraph link parameters in meters */
float             l                                   = 0.07; // m
float             L                                   = 0.09; // m
float             d                                   = 0.0375; // m

float             pantjointRadius                     = 0.005; // m
float             rEE                                 = 0.002; // m


/* generic data for a 2DOF device */
/* joint space */
PVector           angles                              = new PVector(0, 0);
PVector           torques                             = new PVector(0, 0);

/* task space */
PVector           posEE                               = new PVector(0, 0);
PVector           posEELast                           = new PVector(0, 0);
PVector           velEE                               = new PVector(0, 0);
PVector           fEE                                 = new PVector(0, 0); 

/* device graphical position */
PVector           deviceOrigin                        = new PVector(0, 0);

/* World boundaries reference */
final int         worldPixelWidth                     = 1000;
final int         worldPixelHeight                    = 650;

/* graphical elements */
PShape pGraph, joint, joint2, endEffector;
PShape ball, leftWall, bottomWall, rightWall;
PImage scene, img1, img2, img3;

boolean sampling = true;

void setup(){
  /* screen size definition */
  size(1000, 650);
  
  /* device setup */
  haplyBoard          = new Board(this, Serial.list()[1], 0);
  widgetOne           = new Device(widgetOneID, haplyBoard);
  pantograph          = new Pantograph();
  
  widgetOne.set_mechanism(pantograph);
  widgetOne.add_actuator(1, CCW, 2);
  widgetOne.add_actuator(2, CCW, 1);
  widgetOne.add_encoder(1, CCW, 92, 4096, 2);
  widgetOne.add_encoder(2, CCW, 88, 4096, 1);
  widgetOne.device_set_parameters();

  /* visual elements setup */
  background(0);
  deviceOrigin.add(worldPixelWidth/2, 0);

  img1 = loadImage("home.png");
  img2 = loadImage("hostile.png");
  img3 = loadImage("viscous.png");

  scene = img1;

  create_pantagraph();
  frameRate(baseFrameRate);

  SimulationThread st = new SimulationThread();
  scheduler.scheduleAtFixedRate(st, 1, 20, MILLISECONDS);
}


void draw(){
  /* put graphical code here, runs repeatedly at defined framerate in setup, else default at 60fps: */
  if(renderingForce == false){
    background(255);  
    update_animation(angles.x*radsPerDegree, angles.y*radsPerDegree, posEE.x, posEE.y);
  }
}


void keyPressed() {
  if (key == '1') {
    scene = img1;
    sampling = true;
  } else if (key == '2') {
    scene = img2;
    sampling = true;
  }  else if (key == '3') {
    scene = img3;
    sampling = false;
  }
}

class SimulationThread implements Runnable{

  public void run(){

    renderingForce = true;

    if(haplyBoard.data_available()){

      widgetOne.device_read_data();
      angles.set(widgetOne.get_device_angles()); 
      posEE.set(widgetOne.get_device_position(angles.array()));
      posEE.set(device_to_graphics(posEE)); 
      velEE.set((posEE.copy().sub(posEELast)).div(dt));
      posEELast = posEE.copy();

      PVector posEEAni = posEE.copy().mult(pixelsPerMeter);
      if (sampling){
        if (posEEAni.x >= -200 && posEEAni.x < 200
        && posEEAni.y >= 150 && posEEAni.y < 550) {
            color c = scene.get(int((posEEAni.x + 200)/(400./128.)), int((posEEAni.y - 150)/(400./128.)));
            float r = red(c);
            float b = blue(c);
            fEE.x = (r - 127)/127.;
            fEE.y = ((b - 127) * -1)/50.;
        } else {
            fEE.set(0,0);
        }
      } else {
        fEE.set(0,0);
        if(velEE.mag()>1.0){
          println(velEE.mag());
          PVector vEEN = velEE.copy().normalize();
          fEE.x += vEEN.x;
          fEE.y -= vEEN.y;
        }
      }
      println("Forces:" + fEE);

    } else {
       println("NO DATA");
    }

    torques.set(widgetOne.set_device_torques(fEE.array()));
    widgetOne.device_write_torques();

    renderingForce = false;
  }
}


void create_pantagraph(){
  float lAni = pixelsPerMeter * l;
  float LAni = pixelsPerMeter * L;
  float dAni = pixelsPerMeter * d;
  float rEEAni = pixelsPerMeter * rEE;
  float pantjointRadiusAni = pixelsPerMeter * pantjointRadius;

  pGraph = createShape();
  pGraph.beginShape();
  pGraph.noFill();
  pGraph.stroke(0);
  pGraph.strokeWeight(2);

  pGraph.vertex(deviceOrigin.x + dAni/2, deviceOrigin.y);
  pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
  pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
  pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
  pGraph.vertex(deviceOrigin.x - dAni/2, deviceOrigin.y);
  pGraph.endShape(CLOSE);

  joint = createShape(ELLIPSE, deviceOrigin.x + dAni/2, deviceOrigin.y, pantjointRadiusAni, pantjointRadiusAni);
  joint.setStroke(color(0));

  joint2 = createShape(ELLIPSE, deviceOrigin.x - dAni/2, deviceOrigin.y, pantjointRadiusAni, pantjointRadiusAni);
  joint2.setStroke(color(0));

  endEffector = createShape(ELLIPSE, deviceOrigin.x, deviceOrigin.y, 2*rEEAni, 2*rEEAni);
  endEffector.setStroke(color(0));

}


PShape create_wall(float x1, float y1, float x2, float y2){
  x1 = pixelsPerMeter * x1;
  y1 = pixelsPerMeter * y1;
  x2 = pixelsPerMeter * x2;
  y2 = pixelsPerMeter * y2;

  return createShape(LINE, deviceOrigin.x + x1, deviceOrigin.y + y1, deviceOrigin.x + x2, deviceOrigin.y+y2);
}


void update_animation(float th1, float th2, float xE, float yE){
  background(255);

  float lAni = pixelsPerMeter * l;
  float LAni = pixelsPerMeter * L;
  float dAni = pixelsPerMeter * d;

  xE = pixelsPerMeter * xE;
  yE = pixelsPerMeter * yE;

  th1 = 3.14 - th1;
  th2 = 3.14 - th2;

  imageMode(CORNER);
  image(scene, deviceOrigin.x - 200, deviceOrigin.y + 150, 400, 400);

  pGraph.setVertex(1, deviceOrigin.x + dAni/2 + lAni*cos(th1), deviceOrigin.y + lAni*sin(th1));
  pGraph.setVertex(3, deviceOrigin.x - dAni/2 + lAni*cos(th2), deviceOrigin.y + lAni*sin(th2));
  pGraph.setVertex(2, deviceOrigin.x + xE, deviceOrigin.y + yE);

  shape(pGraph);
  shape(joint);
  shape(joint2);
  translate(xE, yE);
  shape(endEffector);

}


PVector device_to_graphics(PVector deviceFrame){
  return deviceFrame.set(-deviceFrame.x, deviceFrame.y);
}


PVector graphics_to_device(PVector graphicsFrame){
  return graphicsFrame.set(-graphicsFrame.x, graphicsFrame.y);
}
