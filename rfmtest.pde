/*
 * Test tracker which sends out test strings for testing HAB listening station
 * RFM22b
 * DL-FLDigi settings: 
 ** 50baud
 ** 460 shift
 ** 8 bits, no parity, 1 stop bit
*/

#include <stdio.h>
#include <util/crc16.h>
#include <SPI.h>
#include <RFM22.h>
 
#define RFM_NSEL_PIN 10
 
int count = 1; 
 
//Setup radio on SPI with NSEL on pin 10
rfm22 radio1(RFM_NSEL_PIN);
 
void setupRadio(){
  delay(3000) ;
  rfm22::initSPI();
  radio1.init();
  delay(500) ;
  radio1.write(0x71, 0x00); // unmodulated carrier
  //This sets up the GPIOs to automatically switch the antenna depending on Tx or Rx state, only needs to be done at start up. 
  // 0b and 0c are swapped (compared to other code) because GPIO0 and GPIO1 are swapped connected to TX_ANT and RX_ANT on this HAB supplies breakout.
  radio1.write(0x0b,0x15);
  radio1.write(0x0c,0x12);
  radio1.setFrequency(434.250);  // frequency, we modulate it in rtty_txbit()
  radio1.write(0x07, 0x08); // turn tx on
  radio1.write(0x6D, 0x04);// turn tx low power 14db = 25mW
 
}

// RTTY Functions - from RJHARRISON's AVR Code
void rtty_txstring (char * string)
{
 
	/* Simple function to sent a char at a time to 
	** rtty_txbyte function. 
	** NB Each char is one byte (8 Bits)
	*/
	char c;
	c = *string++;
	while ( c != '\0')
	{
		rtty_txbyte (c);
		c = *string++;
	}
}
 
void rtty_txbyte (char c)
{
	/* Simple function to sent each bit of a char to 
	** rtty_txbit function. 
	** NB The bits are sent Least Significant Bit first
	**
	** All chars should be preceded with a 0 and 
	** proceded with a 1. 0 = Start bit; 1 = Stop bit
	**
	** ASCII_BIT = 7 or 8 for ASCII-7 / ASCII-8
	*/
	int i;
	rtty_txbit (0); // Start bit
	// Send bits for for char LSB first	
	for (i=0;i<8;i++)
	{
		if (c & 1) rtty_txbit(1); 
			else rtty_txbit(0);	
		c = c >> 1;
	}
	rtty_txbit (1); // Stop bit
        rtty_txbit (1); // Stop bit
}
 
void rtty_txbit (int bit)
{
		if (bit)
		{
		  // high; 0x073 is least significant bit of frequency register, 2x156Hz; 156Hz = smallest frequency adjustment possible on the RFM22b
                  radio1.write(0x073, 0x03);
		}
		else
		{
		  // low
                  radio1.write(0x073, 0x00);
		}
                delayMicroseconds(10000); // For 50 Baud uncomment this and the line below. 
                delayMicroseconds(10150); // You can't do 20150 it just doesn't work as the
                            // largest value that will produce an accurate delay is 16383
                            // See : http://arduino.cc/en/Reference/DelayMicroseconds
 
}

uint16_t gps_CRC16_checksum (char *string)
{
	size_t i;
	uint16_t crc;
	uint8_t c;
 
	crc = 0xFFFF;
 
	// Calculate checksum ignoring the first two $s
	for (i = 2; i < strlen(string); i++)
	{
		c = string[i];
		crc = _crc_xmodem_update (crc, c);
	}
 
	return crc;
}

void setup()
{
  setupRadio() ;
  Serial.begin(9600);
}

void loop() { 
    char superbuffer [150];
    char checksum [10];
    int n;
    
    n=sprintf( superbuffer, "$$REVSPACE,%d,Hello to all intelligent life forms everywhere. And to everyone else out there, the secret is to bang the rocks together, guys.", count);
    if (n > -1){
      n = sprintf (superbuffer, "%s*%04X\n", superbuffer, gps_CRC16_checksum(superbuffer));
      rtty_txstring(superbuffer);
      Serial.println(superbuffer);
    }

    count++;
    
    delay(3000);
}

