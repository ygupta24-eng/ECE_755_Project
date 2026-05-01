# CNN Accelerator UART Wrapper Protocol

## Overview
The UART wrapper provides a serial interface to control and communicate with the CNN accelerator systolic array. It uses a command-based protocol over UART (115200 baud, 8N1).

## Command Format

### General Structure
- **Byte 0**: Command Code
- **Bytes 1+**: Command Parameters (if any)

### Response Format
- **ACK**: `0xAA` for successful command
- **NAK**: `0xEE` for error
- **Data**: Response bytes follow immediately after ACK

---

## Command Reference

### 1. RESET (`0x00`)
**Purpose**: Reset the accelerator core

**Packet**:
```
TX: [0x00]
RX: [0xAA]
```

**Effect**: 
- Sets `acc_rst_n = 0` for one cycle
- Initializes accelerator state

---

### 2. START (`0x01`)
**Purpose**: Begin computation (pulse START signal)

**Packet**:
```
TX: [0x01]
RX: [0xAA]
```

**Effect**:
- Sets `acc_start = 1` for one cycle
- Initiates FILL stage

---

### 3. LOAD HORIZONTAL DATA (`0x10`)
**Purpose**: Provide horizontal boundary inputs

**Packet**:
```
TX: [0x10] [h_in0_byte] [h_in1_byte]
RX: [0xAA]
```

**Parameters**:
- **h_in0_byte**: 6-bit horizontal input 0 (DATA_W=6)
- **h_in1_byte**: 6-bit horizontal input 1

**Effect**:
- Loads `acc_h_in0` and `acc_h_in1` with provided values
- Values are sampled on next clock cycle

**Example** (load h_in0=10, h_in1=20):
```
TX: [0x10] [0x0A] [0x14]
RX: [0xAA]
```

---

### 4. LOAD VERTICAL DATA (`0x11`)
**Purpose**: Provide vertical boundary inputs

**Packet**:
```
TX: [0x11] [v_in0_byte] [v_in1_byte]
RX: [0xAA]
```

**Parameters**:
- **v_in0_byte**: 6-bit vertical input 0
- **v_in1_byte**: 6-bit vertical input 1

**Effect**:
- Loads `acc_v_in0` and `acc_v_in1` with provided values

**Example** (load v_in0=15, v_in1=25):
```
TX: [0x11] [0x0F] [0x19]
RX: [0xAA]
```

---

### 5. LOAD WEIGHTS (`0x12`)
**Purpose**: Load weight values for all 4 columns

**Packet**:
```
TX: [0x12] [w0_byte] [w1_byte] [w2_byte] [w3_byte]
RX: [0xAA]
```

**Parameters**:
- **w0_byte**: 2-bit weight for column 0 (uses bits [1:0])
- **w1_byte**: 2-bit weight for column 1
- **w2_byte**: 2-bit weight for column 2
- **w3_byte**: 2-bit weight for column 3

**Weight Encoding** (2-bit signed):
- `0b00` = +0
- `0b01` = +1
- `0b10` = -2 (or extended precision)
- `0b11` = -1

**Effect**:
- Loads `acc_w_in[0]` through `acc_w_in[3]` with provided values

**Example** (load weights: -1, 0, -1, 0):
```
TX: [0x12] [0x03] [0x00] [0x03] [0x00]
RX: [0xAA]
```

---

### 6. READ PARTIAL SUMS (`0x20`)
**Purpose**: Read computed partial sum outputs

**Packet**:
```
TX: [0x20]
RX: [0xAA] [psum0_lo] [psum1_lo]
```

**Return Values**:
- **psum0_lo**: Low 8 bits of `acc_psum_out0` (13-bit signed value)
- **psum1_lo**: Low 8 bits of `acc_psum_out1`

**Effect**:
- Reads current output values from `acc_psum_out0` and `acc_psum_out1`
- Returns lower 8 bits of 13-bit signed values

**Notes**:
- For complete 13-bit values, software should perform sign extension
- Values are captured combinatorially

**Example Output** (psum0=42, psum1=-15):
```
TX: [0x20]
RX: [0xAA] [0x2A] [0xF1]
```

---

### 7. STATUS (`0x30`)
**Purpose**: Read accelerator status

**Packet**:
```
TX: [0x30]
RX: [0xAA] [status_byte]
```

**Status Byte Format**:
```
Bit 0: acc_done flag
Bit 1: acc_start flag
Bit 2: Reserved
Bits 7-3: Reserved
```

**Effect**:
- Returns current status of accelerator

---

## Usage Example: Full Computation Flow

```
# Reset accelerator
TX: [0x00]
RX: [0xAA]

# Wait 100ms for reset to settle

# Load first horizontal activation pair during FILL stage
TX: [0x10] [0x01] [0x02]  # h_in0=1, h_in1=2
RX: [0xAA]

# Load first vertical activation pair
TX: [0x11] [0x03] [0x04]  # v_in0=3, v_in1=4
RX: [0xAA]

# Load weights (after 4 FILL cycles)
TX: [0x12] [0x03] [0x03] [0x03] [0x03]  # All -1
RX: [0xAA]

# Start computation
TX: [0x01]
RX: [0xAA]

# Wait for computation (observe acc_done via STATUS)

# Read result
TX: [0x20]
RX: [0xAA] [result_lo_0] [result_lo_1]

# Next activation set...
```

---

## Timing Considerations

### Accelerator Sequence
1. **FILL Stage** (8 cycles): Load horizontal/vertical activations
   - Cycles 0-3: Activation inputs only
   - Cycles 4-7: Activation + weight inputs
   
2. **COMPUTE + W_LOAD** (4 cycles): Overlapped computation
   - Compute previous data while loading next weights
   
3. **PSUM_SHIFT** (8 cycles): Drain results from array

### UART Timing
- At 115200 baud: 1 byte ≈ 87 µs
- Multi-byte commands: 87 µs × N bytes
- Typical command latency: <1 ms

### Synchronization
- All accelerator operations synchronous to `clk`
- UART control signals synchronous to `clk`
- Recommend clock ≥ 50 MHz for <1 cycle pipelining

---

## Error Handling

### Common Issues

**Issue**: No ACK received  
**Cause**: 
- Baud rate mismatch
- UART connection issue
- Accelerator in undefined state

**Solution**:
- Verify baud rate (115200)
- Send RESET command

**Issue**: Incorrect results  
**Cause**:
- Timing violation (commands sent too fast)
- Weights loaded at wrong cycle
- Synchronization issue

**Solution**:
- Insert delays between commands (100 µs minimum)
- Verify accelerator lifecycle matches input data

---

## Implementation Checklist

- [ ] UART RX/TX modules instantiated
- [ ] Baud rate configured to 115200
- [ ] CNN accelerator connected to wrapper
- [ ] Protocol parser implemented in host software
- [ ] Test with simple single-activation pattern
- [ ] Verify results match golden reference (badger_tb.sv results)

---

## Reference: Accelerator Pin Mapping

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| clk | 1 | IN | System clock |
| rst_n | 1 | IN | Active-low reset |
| start | 1 | IN | Pulse to begin computation |
| done | 1 | OUT | Computation complete flag |
| h_in0 | 6 | IN | Horizontal input 0 |
| h_in1 | 6 | IN | Horizontal input 1 |
| v_in0 | 6 | IN | Vertical input 0 |
| v_in1 | 6 | IN | Vertical input 1 |
| w_in[3:0] | 2 | IN | Weights per column (4×2 bits) |
| psum_out0 | 13 | OUT | Partial sum from PE10 |
| psum_out1 | 13 | OUT | Partial sum from PE30 |
