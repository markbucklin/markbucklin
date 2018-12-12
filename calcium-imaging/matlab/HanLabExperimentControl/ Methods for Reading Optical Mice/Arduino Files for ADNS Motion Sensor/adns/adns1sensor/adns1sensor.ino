

#include <Arduino.h>
#include <ADNS.h>
#include <SPI.h>

#define CHIPSELECT_PIN  0x05
#define MOUSENUMBER 0x01


ADNS sensor(CHIPSELECT_PIN);
int lastX = 0;

//==================================================================================
//   INITIALIZATION
//==================================================================================
void setup() {
  Serial.begin(115200);
  pinMode(4, OUTPUT);
  pinMode(5, OUTPUT);
  digitalWrite(4, HIGH);
  digitalWrite(5, HIGH);
  pinMode(0x0A, OUTPUT);
  sensor.begin();
  delay(30);
  sensor.dispRegisters();
};

//==================================================================================
//   LOOP
//==================================================================================
void loop() {
  sensor.readXY();
  //if (lastX == sensor.dx())
  //{
  //    Serial.print("x" + String(sensor.dx()) + "y" + String(sensor.dy()));
  //}
  //else
  //{
  //    Serial.println("");
  //    Serial.println(String(CHIPSELECT_PIN) + "x" + String(sensor.dx()) + "y" + String(sensor.dy()));
  // Serial.println("x" + String((int)sensor.dx()) + "y" + String((int)sensor.dy()));
  //}
  //lastX = sensor.dx();
  //FFFFFFFA

//  delay(100); //2

  
  Serial.print(MOUSENUMBER);
  Serial.print("x");
  Serial.print(sensor.dx);
  Serial.print("y");
  Serial.println(sensor.dy);
  
  delay(2); //2
};



