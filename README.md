# UART-with-parity-handling

## Overview

This project implements a **Universal Asynchronous Receiver/Transmitter (UART)** in **VHDL**, featuring configurable baud rates and optional parity checking for reliable serial communication. It was developed as a firmware engineering project to provide practical experience in designing, simulating, implementing and verifying a complete FPGA-based communication system.

The project follows a structured engineering workflow, providing experience in:

* Requirements analysis and capture
* Requirements-based test definition
* Digital system and finite state machine design
* VHDL implementation
* Functional simulation using ModelSim
* FPGA implementation using Xilinx Vivado
* Hardware integration and debugging
* Verification against project requirements
* Project planning and technical presentation

## Project Description

The aim of this project is to design, implement and verify a fully functional **UART Transceiver** using **VHDL**. The design consists of independent transmitter and receiver modules combined within a transceiver wrapper, supporting configurable baud rates and optional parity checking.

The project was developed and tested using **Xilinx Vivado** for FPGA implementation and **ModelSim** for simulation and verification.

## Key Features

### UART Transmitter

The transmitter module is responsible for serialising parallel data and transmitting it according to the UART protocol.

Features include:

* Transmission of serial UART data
* Optional parity bit generation
* Configurable baud rate
* 50 MHz system clock operation
* Synchronous reset functionality
* Fully verified using a dedicated ModelSim testbench

### UART Receiver

The receiver module reconstructs serial data into parallel data while monitoring communication integrity.

Features include:

* UART serial data reception
* Optional parity checking for error detection
* Configurable baud rate
* 50 MHz system clock operation
* Synchronous reset functionality
* Fully verified using a dedicated ModelSim testbench

### UART Transceiver Wrapper

The top-level transceiver integrates both transmitter and receiver into a single design.

Features include:

* Combines UART transmitter and receiver modules
* Supports end-to-end UART communication
* Shared configurable baud rate
* System-level simulation and verification using ModelSim

## Key Requirements

### General

* Operates using a **50 MHz system clock**.
* Supports configurable UART baud rates.
* Includes synchronous reset functionality.
* Designed using modular VHDL architecture.
* Fully simulated and verified before FPGA implementation.

### Transmitter

* Accepts serial data from the receiver component.
* Generates and transmits parity when enabled.
* Outputs UART serial data.
* Operates from the system clock.
* Includes dedicated testbench verification.

### Receiver

* Receives UART serial data.
* Supports optional parity checking.
* Detects communication errors when parity is enabled.
* Operates from the system clock.
* Includes dedicated testbench verification.

### Transceiver

* Integrates the transmitter and receiver into a complete UART system.
* Supports end-to-end communication testing.
* Includes a comprehensive system-level testbench.

## Target Hardware

The project was developed for the **Xilinx Arty A7-50T FPGA Development Board**.

### Inputs

* 50 MHz system clock
* Push button
* Slide switch

### Outputs

* Two seven-segment (HEX) displays

## Development Tools

* VHDL-2008
* Xilinx Vivado
* ModelSim

## Project Purpose

This project demonstrates the complete development of a hardware-based UART communication system using FPGA technology. It showcases the design of modular transmitter and receiver architectures, configurable baud rate generation, optional parity generation and checking for error detection, finite state machine implementation, synchronisation techniques, simulation, verification and successful hardware integration.

The project reinforces core digital design principles while providing practical experience with the complete FPGA firmware development lifecycle, from requirements capture through implementation, testing and verification.
