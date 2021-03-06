// modified from http://forums.electricimp.com/discussion/209/hannah-accelerometer-interrupts/p1
// Color Blink code example for Hannah
 
// IO Expander Class for SX1509
class IoExpander
{
    i2cPort = null;
    i2cAddress = null;
 
    constructor(port, address)
    {
        if(port == I2C_12)
        {
            // Configure I2C bus on pins 1 & 2
            hardware.configure(I2C_12);
            i2cPort = hardware.i2c12;
        }
        else if(port == I2C_89)
        {
            // Configure I2C bus on pins 8 & 9
            hardware.configure(I2C_89);
            i2cPort = hardware.i2c89;
        }
        else
        {
            server.log("Invalid I2C port specified.");
        }
 
        i2cAddress = address << 1;
    }
 
    // Read a byte
    function read(register)
    {
        local data = i2cPort.read(i2cAddress, format("%c", register), 1);
        if(data == null)
        {
            server.log("I2C Read Failure");
            return -1;
        }
 
        return data[0];
    }
 
    // Write a byte
    function write(register, data)
    {
        i2cPort.write(i2cAddress, format("%c%c", register, data));
    }
 
    // Write a bit to a register
    function writeBit(register, bitn, level)
    {
        local value = read(register);
        value = (level == 0)?(value & ~(1<<bitn)):(value | (1<<bitn));
        write(register, value);
    }
 
    // Write a masked bit pattern
    function writeMasked(register, data, mask)
    {
       local value = read(register);
       value = (value & ~mask) | (data & mask);
       write(register, value);
    }
 
    // Set a GPIO level
    function setPin(gpio, level)
    {
        writeBit(gpio>=8?0x10:0x11, gpio&7, level?1:0);
    }
 
    // Set a GPIO direction
    function setDir(gpio, output)
    {
        writeBit(gpio>=8?0x0e:0x0f, gpio&7, output?0:1);
    }
 
    // Set a GPIO internal pull up
    function setPullUp(gpio, enable)
    {
        writeBit(gpio>=8?0x06:0x07, gpio&7, enable);
    }
 
    // Set GPIO interrupt mask
    function setIrqMask(gpio, enable)
    {
        writeBit(gpio>=8?0x12:0x13, gpio&7, enable);
    }
 
    // Set GPIO interrupt edges
    function setIrqEdges(gpio, rising, falling)
    {
        local addr = 0x17 - (gpio>>2);
        local mask = 0x03 << ((gpio&3)<<1);
        local data = (2*falling + rising) << ((gpio&3)<<1);    
        writeMasked(addr, data, mask);
    }
 
    // Clear an interrupt
    function clearIrq(gpio)
    {
        writeBit(gpio>=8?0x18:0x19, gpio&7, 1);
    }
 
    // Get a GPIO input pin level
    function getPin(gpio)
    {
        return (read(gpio>=8?0x10:0x11)&(1<<(gpio&7)))?1:0;
    }
}
 
// RGB LED Class
class RgbLed extends IoExpander
{
    // IO Pin assignments
    pinR = null;
    pinG = null;
    pinB = null;
 
    constructor(port, address, r, g, b)
    {
        base.constructor(port, address);
 
        // Save pin assignments
        pinR = r;
        pinG = g;
        pinB = b;
 
        // Disable pin input buffers
        writeBit(pinR>7?0x00:0x01, pinR>7?(pinR-7):pinR, 1);
        writeBit(pinG>7?0x00:0x01, pinG>7?(pinG-7):pinG, 1);
        writeBit(pinB>7?0x00:0x01, pinB>7?(pinB-7):pinB, 1);
 
        // Set pins as outputs
        writeBit(pinR>7?0x0E:0x0F, pinR>7?(pinR-7):pinR, 0);
        writeBit(pinG>7?0x0E:0x0F, pinG>7?(pinG-7):pinG, 0);
        writeBit(pinB>7?0x0E:0x0F, pinB>7?(pinB-7):pinB, 0);
 
        // Set pins open drain
        writeBit(pinR>7?0x0A:0x0B, pinR>7?(pinR-7):pinR, 1);
        writeBit(pinG>7?0x0A:0x0B, pinG>7?(pinG-7):pinG, 1);
        writeBit(pinB>7?0x0A:0x0B, pinB>7?(pinB-7):pinB, 1);
 
        // Enable LED drive
        writeBit(pinR>7?0x20:0x21, pinR>7?(pinR-7):pinR, 1);
        writeBit(pinG>7?0x20:0x21, pinG>7?(pinG-7):pinG, 1);
        writeBit(pinB>7?0x20:0x21, pinB>7?(pinB-7):pinB, 1);
 
        // Set to use internal 2MHz clock, linear fading
        write(0x1e, 0x50);
        write(0x1f, 0x10);
 
        // Initialise as inactive
        setLevels(0, 0, 0);
        setPin(pinR, 0);
        setPin(pinG, 0);
        setPin(pinB, 0);
    }
 
    // Set LED enabled state
    function setLed(r, g, b)
    {
        if(r != null) writeBit(pinR>7?0x20:0x21, pinR&7, r);
        if(g != null) writeBit(pinG>7?0x20:0x21, pinG&7, g);
        if(b != null) writeBit(pinB>7?0x20:0x21, pinB&7, b);
    }
 
    // Set red, green and blue intensity levels
    function setLevels(r, g, b)
    {
        if(r != null) write(pinR<4?0x2A+pinR*3:0x36+(pinR-4)*5, r);
        if(g != null) write(pinG<4?0x2A+pinG*3:0x36+(pinG-4)*5, g);
        if(b != null) write(pinB<4?0x2A+pinB*3:0x36+(pinB-4)*5, b);
    }
}
 
 
// Construct an LED
local led = RgbLed(I2C_89, 0x3E, 7, 5, 6);
 
// Main loop
function update()
{
    // Schedule the next change
    imp.wakeup(1.0, update);
 
    local r = 99;

    // Set the LED color
    // off = led.setLevels(1,1,1);
    if(counter == 1) led.setLevels(r, 0, 0);
    if(counter == 2) led.setLevels(0, r, 0);
    if(counter == 3) {
      led.setLevels(0, 0, r);
      counter = 0
    }
    counter++; 
}
 
// Register with the server
imp.configure("RGB LED blinking", [], []);
 
// Enable the LED outputs and start color changing
//led.setLed(1, 1, 1);
update();
 
// End of code.