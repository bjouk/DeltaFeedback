// This code is for an arduino that outputs stims only, the PD inputs go straight to MCU. This allows to change the hole numbers (order_chan)

// Initialising variables
//------------------------------
// Matlab switches this value to 5 when theæ experiment starts and 6 to switch it off
unsigned long wait = 490; // delay period for mode 3 & 4
int sound=0; //0=Tone sound ; 1=Gaussian sound
int order=6;
char inputBuffer[10];
//------------------------------
// setting up pin identity
//------------------------------
void setup() {   
  Serial.begin(9600) ; 
  // send Tone (TuckerDavis)
  //------------------------  
  pinMode(30,OUTPUT);    // Tone Frequency #1
  digitalWrite(30, LOW);
  pinMode(28,OUTPUT);    // Tone Frequency #1 digitalIO
 digitalWrite(28, LOW);
  pinMode(26,OUTPUT);    // Tone Frequency #1 digitalIO2
  digitalWrite(26, LOW);
  pinMode(24,OUTPUT);    // Tone Frequency #1 digitalIO3
  digitalWrite(24, LOW);
  pinMode(22,OUTPUT);    // Tone Frequency #1 digitalIO4
  digitalWrite(22, LOW);
  pinMode(40,OUTPUT);    // Trigger video
  digitalWrite(40, LOW);
  //------------------------------
  // send Tone (Intan Device)
  //------------------------  
  pinMode(23,OUTPUT);    // mode 1: tone without delay
  digitalWrite(23, LOW);
  pinMode(27,OUTPUT);    // mode 3: tone with DELAY 
  digitalWrite(27, LOW);
  pinMode(29,OUTPUT);    // mode 0: no tone
  digitalWrite(29, LOW);

  //------------------------------
  
  Serial.flush();}
  

// main algorithm
//------------------------------
void loop(){
  // ---------------------------------------------------------------------------
  // receive MATLAB information, send tone trigger to TDT, and TTL to Intan Device
  // ---------------------------------------------------------------------------
  if (Serial.available() >0){
    order=Serial.read();
    if(order>=00 && order<70){
      sound=order%10;// sound is the unit of the serial reading
      order=order/10;// order is the decade of the serial reading
    }
    Serial.flush(); 
    //--------------------------------------------------------------------------
    // mode 1: direct tone
    //--------------------------------------------------------------------------
    if (sound==0) { // select tone mode
      digitalWrite(24,LOW);
      digitalWrite(28,LOW);
      }
    if(sound==1) {
      digitalWrite(24,LOW);
      digitalWrite(28,HIGH);
    }
    if (sound==2) {
      digitalWrite(24,HIGH);
      digitalWrite(28,LOW);
    }
     if (sound==3) {
      digitalWrite(24,HIGH);
      digitalWrite(28,HIGH);
    }
    
    if (order==1){
    
    digitalWrite(27,HIGH);    //Intan event      
    delay(10);
    digitalWrite(27,LOW);
        
    digitalWrite(30,HIGH);    //TDT
    delay(10);
    digitalWrite(30,LOW);
    
    digitalWrite(22,HIGH);    //Trigger digital
    delay(10);
    digitalWrite(22,LOW);}    
    //--------------------------------------------------------------------------
   
    //--------------------------------------------------------------------------
    // mode 3: delayed tone
    //--------------------------------------------------------------------------
    if (order==3){

    delay(wait);
      
    digitalWrite(27,HIGH);    //Intan event      
    delay(10);
    digitalWrite(27,LOW);
    
    digitalWrite(30,HIGH);    //TDT
    delay(10);
    digitalWrite(30,LOW);}    
    //--------------------------------------------------------------------------
   
    //--------------------------------------------------------------------------
    // mode 0: no tone (detection only)
    //--------------------------------------------------------------------------
    if (order==0){
    digitalWrite(29,HIGH);    //Intan event      
    delay(10);
    digitalWrite(29,LOW);}
    //--------------------------------------------------------------------------
     //--------------------------------------------------------------------------
    // mode 6: trigger video
    //--------------------------------------------------------------------------
    if (order==6){
    digitalWrite(40,HIGH);    //Intan event      
    delay(10);
    }
    //--------------------------------------------------------------------------
    
    
}
//------------------------------
}











