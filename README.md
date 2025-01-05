# Pick and Place Feeder Project

![Prototype Feeder Advancing](docs/images/feed.gif)

## Overview
The aim of this project is to design a low cost powered and addressable pick and place feeder. Other pnp feeders exist but didn't meet my design requirements or were too expensive to justify having 100+ feeders.

This project aims to solve these challenges by providing an easy-to-use, modular, and affordable feeder system that can be used with both the Neoden 4 and Lumen PnP machines.

## Design Goals

1. **Compatibility**
   - Design a powered, pick and place feeder compatible with Neoden 4 and OpenPNP machines.
   - Support component sizes down to 0201.

2. **Low Cost**
   - Keep the BOM cost per feeder unit under $10 to make the solution accessible and affordable for hobbyists and small manufacturers.

3. **Fast Production**
   - Limit 3D printing time per unit to less than 2 hours using a standard consumer-grade 3D printer.
   - Assembly time less than 10 minutes per feeder

4. **Ease of Use**
   - Ensure quick part loading to minimize the setup time.
   - Allow preloaded cartridges for efficient part swapping, avoiding the need to load components directly into the machine.

5. **Scalability**
   - Support up to 512 feeders on a single master device to enable integration into a larger inventory system, such as with InvenTree.

## Block Diagrams

### System Block Diagram
![System Block Diagram](docs/images/system_block_diagram.png)

The system block diagram illustrates the two boards involved in the design: the feeder and the backplane board. One backplane board acts as the host, from either being connected to a PC or getting data from the host UART bus. Additional backplane boards can be attached and act as slaves to allow for up to 512 feeders from one host which sends RS-485 data and power. This scalability makes the system suitable for use as an inventory system. Power can be supplied at either 24V or 12V.

### Feeder Block Diagram
![Feeder Block Diagram](docs/images/feeder_block_diagram.png)

The feeder block diagram shows that each feeder has a very simple board, just an EEPROM for storing MPN, quantity, feed distance and any other metadata, as well as a header for the SG90 servo motor., which controls an SG90 servo motor responsible for advancing the tape forwards. 

## Progress Checklist

1. [X] System Level Block Diagram
2. [X] Feeder Block Diagram
3. [X] Backplane Block Diagram
4. [X] MVP Feeder Hardware Prototype
5. [X] Feeder Positioning Accuracy Testing
6. [X] Feeder Lifespan Testing
7. [ ] Neoden 4 Data Packet Reverse Engineering
8. [X] Mechanical Footprint Design
9. [X] Feeder PCB Layout
10. [X] Feeder Schematic
11. [X] Backplane PCB Layout
12. [X] Backplane PCB Schematic
13. [ ] Order PCBs and test
14. [ ] System Integration and Testing
15. [ ] Support OpenPNP

## Contributing
Contributions are welcome! Please check the progress checklist above and feel free to open issues or submit pull requests for any ongoing tasks.

## License
This project is licensed under the MIT License - see the LICENSE file for details.
