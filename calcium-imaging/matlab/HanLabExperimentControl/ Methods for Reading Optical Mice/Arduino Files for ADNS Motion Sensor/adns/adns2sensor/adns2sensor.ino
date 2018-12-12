/*
adns2sensor.ino
Mark Bucklin 5/22/2014

Works with ADNS library (Mark Bucklin) to pass [dx,dy] measurements from two
ADNS-9800 laser mouse sensors (placed 45-degrees apart on surface of styrofoam ball).

*/


#include <ADNS.h>

#define CHIPSELECT_PIN1  0x04
#define CHIPSELECT_PIN2  0x05
#define MOUSENUMBER1     0x01
#define MOUSENUMBER2     0x02


ADNS leftSensor(CHIPSELECT_PIN1);
ADNS rightSensor(CHIPSELECT_PIN2);

//==================================================================================
//   INITIALIZATION
//==================================================================================
void setup() {
  Serial.begin(115200);
  digitalWrite(CHIPSELECT_PIN1, HIGH);
  digitalWrite(CHIPSELECT_PIN2, HIGH);
  digitalWrite(SS_ARDUINO, HIGH);
  pinMode(SS_ARDUINO, OUTPUT);
  pinMode(CHIPSELECT_PIN1, OUTPUT);
  pinMode(CHIPSELECT_PIN2, OUTPUT);
  
  delay(100);
  leftSensor.begin();
  delay(1);
  rightSensor.begin();
  delay(45);


  //leftSensor.writeRegister( 0x20, 0x02);
  //rightSensor.writeRegister( 0x20, 0x02);

  //rightSensor.setResolution(1000);
  //leftSensor.setResolution(1000);

  
//  delay(100);
//  leftSensor.begin();
//  delay(1);
//  rightSensor.begin();
//  delay(45);
};




//==================================================================================
//   LOOP
//==================================================================================
void loop() {
  
  //   Read from Sensor
  leftSensor.readXY();
  rightSensor.readXY();

 
  // Send Left Sensor Values to Computer
  Serial.print(MOUSENUMBER1);
  Serial.print("x");
  Serial.print(leftSensor.dx);
  Serial.print("y");
  Serial.println(leftSensor.dy);

  //Serial.print("   ");
  
  // Send Right Sensor Values to Computer
  Serial.print(MOUSENUMBER2);
  Serial.print("x");
  Serial.print(rightSensor.dx);
  Serial.print("y");
  Serial.println(rightSensor.dy);
  
  delay(50);


  //leftSensor.dispRegisters();
  //rightSensor.dispRegisters();
  
};












 
//if (leftSensor.readRegister(REG_Motion)){
//leftSensor.readXY();
//  // Send Left Sensor Values to Computer
//  Serial.print(MOUSENUMBER1);
//  Serial.print("x");
//  Serial.print(leftSensor.dx);
//  Serial.print("y");
//  Serial.println(leftSensor.dy);
//};
//
//if (leftSensor.readRegister(REG_Motion)){
//  rightSensor.readXY();
// // Send Right Sensor Values to Computer
//  Serial.print(MOUSENUMBER2);
//  Serial.print("x");
//  Serial.print(rightSensor.dx);
//  Serial.print("y");
//  Serial.println(rightSensor.dy);
//};
