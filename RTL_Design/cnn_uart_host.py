#!/usr/bin/env python3
"""
CNN Accelerator UART Interface - Python Host Controller

This script demonstrates how to communicate with the CNN accelerator 
over UART from a host computer (e.g., PC, Raspberry Pi).

Requirements:
    - pyserial: pip install pyserial

Usage:
    python3 cnn_uart_host.py --port /dev/ttyUSB0 --baud 115200

Protocol commands:
    0x00 - RESET
    0x01 - START
    0x10 - LOAD HORIZONTAL DATA
    0x11 - LOAD VERTICAL DATA
    0x12 - LOAD WEIGHTS
    0x20 - READ PARTIAL SUMS
    0x30 - READ STATUS
"""

import serial
import argparse
import time
import struct
from typing import Tuple, List


class CNNUARTController:
    """Controller for CNN accelerator via UART"""
    
    # Command codes
    CMD_RESET      = 0x00
    CMD_START      = 0x01
    CMD_H_DATA     = 0x10
    CMD_V_DATA     = 0x11
    CMD_WEIGHTS    = 0x12
    CMD_READ_PSUM  = 0x20
    CMD_STATUS     = 0x30
    
    # Response codes
    ACK = 0xAA
    NAK = 0xEE
    
    def __init__(self, port: str, baud: int = 115200, timeout: float = 1.0):
        """
        Initialize UART connection
        
        Args:
            port: Serial port (e.g., '/dev/ttyUSB0', 'COM3')
            baud: Baud rate (default 115200)
            timeout: Read timeout in seconds
        """
        self.ser = serial.Serial(port=port, baudrate=baud, timeout=timeout)
        self.port = port
        self.baud = baud
        print(f"Connected to {port} at {baud} baud")
        time.sleep(0.5)  # Let connection stabilize
    
    def close(self):
        """Close serial connection"""
        self.ser.close()
    
    def _send_bytes(self, data: bytes):
        """Send bytes over UART"""
        self.ser.write(data)
        self.ser.flush()
    
    def _read_bytes(self, count: int) -> bytes:
        """Read bytes from UART with timeout"""
        data = self.ser.read(count)
        if len(data) < count:
            raise TimeoutError(f"Expected {count} bytes, got {len(data)}")
        return data
    
    def _send_command(self, cmd: int, *args: int) -> Tuple[bool, bytes]:
        """
        Send command and wait for response
        
        Args:
            cmd: Command code
            *args: Command arguments
        
        Returns:
            (success, response_data)
        """
        packet = bytes([cmd] + list(args))
        print(f"  TX: {' '.join(f'{b:02X}' for b in packet)}")
        
        self._send_bytes(packet)
        
        # Read ACK/NAK
        try:
            response = self._read_bytes(1)
            if response[0] == self.ACK:
                print(f"  RX: ACK")
                return True, b''
            elif response[0] == self.NAK:
                print(f"  RX: NAK")
                return False, b''
            else:
                print(f"  RX: {response[0]:02X}")
                return False, response
        except TimeoutError:
            print("  RX: TIMEOUT")
            return False, b''
    
    def reset(self) -> bool:
        """Reset accelerator"""
        print("RESET accelerator")
        success, _ = self._send_command(self.CMD_RESET)
        time.sleep(0.1)
        return success
    
    def start(self) -> bool:
        """Start computation"""
        print("START computation")
        success, _ = self._send_command(self.CMD_START)
        return success
    
    def load_h_data(self, h_in0: int, h_in1: int) -> bool:
        """
        Load horizontal activation data
        
        Args:
            h_in0: Horizontal input 0 (6 bits)
            h_in1: Horizontal input 1 (6 bits)
        """
        print(f"LOAD horizontal data: h_in0={h_in0:02X}, h_in1={h_in1:02X}")
        success, _ = self._send_command(self.CMD_H_DATA, h_in0, h_in1)
        time.sleep(0.01)  # 10ms between commands
        return success
    
    def load_v_data(self, v_in0: int, v_in1: int) -> bool:
        """
        Load vertical activation data
        
        Args:
            v_in0: Vertical input 0 (6 bits)
            v_in1: Vertical input 1 (6 bits)
        """
        print(f"LOAD vertical data: v_in0={v_in0:02X}, v_in1={v_in1:02X}")
        success, _ = self._send_command(self.CMD_V_DATA, v_in0, v_in1)
        time.sleep(0.01)
        return success
    
    def load_weights(self, weights: List[int]) -> bool:
        """
        Load weight values
        
        Args:
            weights: List of 4 weight values (2 bits each)
                    [w0, w1, w2, w3] where each is 0-3
        """
        if len(weights) != 4:
            print("ERROR: Expected 4 weights")
            return False
        
        print(f"LOAD weights: {weights}")
        success, _ = self._send_command(self.CMD_WEIGHTS, *weights)
        time.sleep(0.01)
        return success
    
    def read_psum(self) -> Tuple[bool, int, int]:
        """
        Read partial sum results
        
        Returns:
            (success, psum0_lo, psum1_lo)
        """
        print("READ partial sums")
        self._send_bytes(bytes([self.CMD_READ_PSUM]))
        
        try:
            ack = self._read_bytes(1)
            if ack[0] != self.ACK:
                print(f"  RX: NAK")
                return False, 0, 0
            
            psum0_lo = self._read_bytes(1)[0]
            psum1_lo = self._read_bytes(1)[0]
            
            print(f"  RX: ACK psum0_lo={psum0_lo:02X} psum1_lo={psum1_lo:02X}")
            return True, psum0_lo, psum1_lo
        except TimeoutError:
            print("  RX: TIMEOUT")
            return False, 0, 0
    
    def read_status(self) -> Tuple[bool, int]:
        """
        Read accelerator status
        
        Returns:
            (success, status_byte)
        """
        print("READ status")
        self._send_bytes(bytes([self.CMD_STATUS]))
        
        try:
            ack = self._read_bytes(1)
            if ack[0] != self.ACK:
                print(f"  RX: NAK")
                return False, 0
            
            status = self._read_bytes(1)[0]
            print(f"  RX: ACK status={status:02X}")
            return True, status
        except TimeoutError:
            print("  RX: TIMEOUT")
            return False, 0


def main():
    """Example usage of CNN UART controller"""
    
    parser = argparse.ArgumentParser(description='CNN Accelerator UART Controller')
    parser.add_argument('--port', type=str, default='/dev/ttyUSB0',
                       help='Serial port (default: /dev/ttyUSB0)')
    parser.add_argument('--baud', type=int, default=115200,
                       help='Baud rate (default: 115200)')
    args = parser.parse_args()
    
    try:
        # Create controller
        controller = CNNUARTController(args.port, args.baud)
        
        print("\n" + "="*60)
        print("CNN UART Test Sequence")
        print("="*60 + "\n")
        
        # Test sequence
        controller.reset()
        time.sleep(0.5)
        
        # Load data
        controller.load_h_data(0x01, 0x02)
        controller.load_v_data(0x03, 0x04)
        controller.load_weights([3, 3, 3, 3])  # All -1
        
        # Start computation
        controller.start()
        
        # Wait for completion
        print("\nWaiting for computation...")
        time.sleep(1.0)
        
        # Read results
        success, psum0, psum1 = controller.read_psum()
        
        if success:
            print(f"\nResults:")
            print(f"  psum_out0 (LSB) = {psum0}")
            print(f"  psum_out1 (LSB) = {psum1}")
        
        # Close connection
        controller.close()
        print("\nDone!")
        
    except serial.SerialException as e:
        print(f"Serial error: {e}")
    except Exception as e:
        print(f"Error: {e}")


if __name__ == '__main__':
    main()
