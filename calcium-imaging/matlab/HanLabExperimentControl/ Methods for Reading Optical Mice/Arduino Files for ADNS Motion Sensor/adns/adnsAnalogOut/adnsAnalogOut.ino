/*
adnsAnalogOut.ino
Mark Bucklin 5/22/2014

Works with ADNS library (Mark Bucklin) to give rotation around 3 axes 
(from 2 ADNS-9800 laser mouse sensors placed 45-degrees apart) as an analog signal.
Pins 3, 5, and 6 should be connected to a simple lowpass filter. A decent filter uses
a 2.2uF capacitor and a 10K resistor.
*/

#include <Arduino.h>
#include <ADNS.h>
#include <SPI.h>

#define CHIPSELECT_PIN1  0x08
#define CHIPSELECT_PIN2  0x09
#define XROT_PIN  0x03
#define YROT_PIN  0x05
#define ZROT_PIN  0x06
#define DEBUG  0x00


ADNS leftSensor(CHIPSELECT_PIN1);
ADNS rightSensor(CHIPSELECT_PIN2);
byte neutralDuty = 127;
const int xrotscale = 2;
const int yrotscale = 2;
const int zrotscale = 2;

//==================================================================================
//   INITIALIZATION
//==================================================================================
void setup() {
  Serial.begin(115200);
  // Sensor Pins (SPI)
  pinMode(CHIPSELECT_PIN1, OUTPUT);
  pinMode(CHIPSELECT_PIN2, OUTPUT);
  digitalWrite(CHIPSELECT_PIN1, HIGH);
  digitalWrite(CHIPSELECT_PIN2, HIGH);
  pinMode(0x0A, OUTPUT);
  // Analog Output Pins (PWM)
  pinMode(XROT_PIN, OUTPUT);
  pinMode(YROT_PIN, OUTPUT);
  pinMode(ZROT_PIN, OUTPUT);
  // Begin Sensors
  leftSensor.begin();
  delay(1);
  rightSensor.begin();
  delay(45);
};

//==================================================================================
//   LOOP
//==================================================================================
void loop() {
  // Read from Sensor
  leftSensor.readXY();
  rightSensor.readXY();
  // Combine Readings from Left & Right Sensors for ROTATION AROUND 3 AXES
  int xrot = (leftSensor.dy + rightSensor.dy) * xrotscale;
  int yrot = (leftSensor.dy - rightSensor.dy) * yrotscale;
  int zrot = (leftSensor.dx + rightSensor.dx) * zrotscale;

  // Update Analog Output (via PWM duty cycle set between 0-255)
  xrot += neutralDuty;
  yrot += neutralDuty;
  zrot += neutralDuty;
  xrot = constrain(xrot, 0, 255);
  yrot = constrain(yrot, 0, 255);
  zrot = constrain(zrot, 0, 255);
  analogWrite(XROT_PIN, (byte)xrot);
  analogWrite(YROT_PIN, (byte)yrot);
  analogWrite(ZROT_PIN, (byte)zrot);

#if DEBUG == 1
  Serial.print("xrot:");
  Serial.print(xrot);
  Serial.print("\t\tyrot:");
  Serial.print(yrot);
  Serial.print("\t\tzrot:");
  Serial.println(zrot);
#endif
  delay(1);
};

