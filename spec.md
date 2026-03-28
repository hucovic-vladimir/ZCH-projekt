# ZCH Project - 3x3 Convolution Filter

## Overview
- The design reads a 64x64 pixel grayscale image from a provided address in input RAM, applies a 3x3 convolution filter, and writes the processed 62x62 
  image to specified address in output RAM.
- The user can use configuration registers to choose between 4 provided filters, stored in ROM. 

## Block schema

![Block schema](./ZCH.svg)

https://github.com/hucovic-vladimir/ZCH-projekt/blob/main/ZCH.svg

## I/O specification

### Inputs
- CLOCK
- RESET - Resets all internal signals and configuration registers to default values, stops computation
- CFG_WRITE_EN - Enables write to configuration registers (modify filter selection, starting input/output address).
- FILTER_SELECTION_IN [1:0] - 2 bit signal to select the applied filter:
    - 00 => Sharpening
    - 01 => Gaussian smoothing
    - 10 => Vertical edge detection
    - 11 => Horizontal edge detection
- IN_ADDR [15:0] - Address of the first pixel of the input image (in input RAM).
- OUT_ADDR [15:0] - Address where the first byte of the output will be written (in output RAM).
- ENABLE - On rising edge, start the computation.
- Input image expected on IN_ADDR in input RAM.


### Outputs
- BUSY - 1 if convolution currently in progress, 0 if ready to start
- OUTPUT_READY - 1 after entire image processed and written to memory 
- ERROR - Set to 1 on error, e.g. input/output address too high or ENABLE set to high when BUSY = 1
- Processed image written to output memory at user-specified address

## Block description

### Configuration block
- Stores user configuration (selected filter, I/O addresses)

### Filter ROM  
- Stores kernel weights / scaling factor of filters
- Provides them to convolution pipeline when computation starts

### Input RAM 
- Contains input image

### Read address generator + line buffers 
- Translates row and column numbers into memory address
- Buffer stores 3 lines of input image at a time
- Constructs sliding 3×3 windows and passes them to convolution pipeline 

### Convolution pipeline  
- Handles convolution
    - Multiply using 9 multipliers
    - Accumulate with adder tree
    - Apply scaling
    - Clamp to <0, 255>

### Write address generator + output buffer 
- Stores result from convolution pipeline, computes the address and writes to output memory 

### Output RAM
- Contains the final 62×62 filtered image

### FSM (not in diagram, connected to everything except memory)
- Sends/receives internal control signals, keeps state of computation.


## Test cases

### Happy-path test cases (1 per filter type)
    - Tests: Correct convolution result and normal control-signal behavior for each filter
    - Inputs
        - Random IN and OUT addresses (not out of range)
        - Randomly generated images
    - Expected output
        - ERROR low,
        - BUSY high during computation,
        - OUTPUT_READY high for 1 clock cycle after computation finishes, then cleared
        - Expected image (obtained with Python script) written to correct address

### Error test case 1 + recovery
    - Tests: Detection of out-of-range addresses and successful recovery on the next valid run
    - 1st Input:
        - Set starting input/output address out-of-range
    - Expected output:
        - ERROR high for 1 clock cycle, then cleared
        - No write to output memory
    - 2nd Input:
        - Correct address, randomly generated image
    - Expected output:
        - ERROR low
        - OUTPUT_READY high for 1 clock cycle after computation finishes, then cleared
        - Expected image written to specified address

### Error test case 2
    - Tests: Rejection of a new ENABLE request while computation is already in progress
    - Input:
        - Valid address, random, image, ENABLE = 1
        - Set ENABLE to 1 again during computation
    - Expected output: 
        - ERROR high for 1 clock cycle, previous computation continues

### Configuration test
    - Tests: Configuration registers do not change when CFG_WRITE_EN is low
    - Input:
        - Valid addresses, filter selection
        - CFG_WRITE_EN low
    - Expected output:
        - Configuration registers remain unchanged

### Boundary address still works
    - Tests: Correct operation at the highest valid input and output start addresses
    - Input:
        - Set IN_ADDR and OUT_ADDR to the highest valid starting addresses that still allow reading the full 64x64 input image and writing the full 62x62 output image
        - Use a randomly generated image and valid filter selection
    - Expected output:
        - ERROR low
        - BUSY high during computation
        - OUTPUT_READY high for 1 clock cycle after computation finishes, then cleared
        - Expected image written to the specified output address range

### RESET test
    - Tests: RESET initializes control signals and configuration registers and stops active computation
    - Input:
        - Assert RESET
    - Expected output:
        - BUSY low
        - OUTPUT_READY low
        - ERROR low
        - Configuration registers set to their default values
        - Ongoing computation stopped

### Clamp / overflow test
    - Tests: Convolution results are correctly clamped to the valid output range
    - Input:
        - Valid addresses and filter selection
        - Image values chosen so convolution produces intermediate results below 0 and above 255
    - Expected output:
        - ERROR low
        - BUSY high during computation
        - OUTPUT_READY high for 1 clock cycle after computation finishes, then cleared
        - All output pixel values clamped to the range <0, 255>
    


