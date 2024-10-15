# Pick and Place Feeder Project

![Prototype Feeder Advancing](docs/images/feed.gif)

## Overview
The aim of this project is to design a powered and addressable pick and place feeder for less than $25 fully assembled and tested. Other pnp feeders exist but didn't meet my design requirements or were too expensive to justify having 200+ feeders.

This project aims to solve these challenges by providing an easy-to-use, modular, and affordable feeder system that can be used with both the Neoden 4 and Lumen PnP machines.

## Design Goals

1. **Compatibility**
   - Design a powered, addressable pick and place feeder compatible with Neoden 4 and Lumen PnP machines.
   - Support component sizes down to 0402.

2. **Low Cost**
   - Keep the BOM cost per feeder unit under $10 to make the solution accessible and affordable for hobbyists and mid scale manufacturing.

3. **Fast Production**
   - Limit 3D printing time per unit to less than 2 hours using a standard consumer-grade 3D printer.
   - Assembly time less than 10 minutes per feeder.

4. **Ease of Use**
   - Ensure quick part loading to minimize the setup time.
   - Allow preloaded cartridges for efficient part swapping, avoiding the need to load components directly into the machine.

5. **Scalability**
   - Support up to 256 feeders on a single master device to enable integration into a larger inventory system, such as with InvenTree.

## Block Diagrams

### System Block Diagram
![System Block Diagram](docs/images/system_block_diagram.png)

The system block diagram illustrates the two main boards involved in the design: the feeder and the backplane. The backplane contains a master controller that distributes power and uses a CAN physical interface for UART communication, sending Modbus data packets to each of the feeders. The backplane supports 8 addressing bits per feeder, allowing up to 256 feeders to be connected to a single master controller. This scalability makes the system suitable for use as an inventory system. Power can be supplied at either 24V or 12V.

### Feeder Block Diagram
![Feeder Block Diagram](docs/images/feeder_block_diagram.png)

The feeder block diagram shows that each feeder is equipped with an RP2040 microcontroller, which controls an SG90 servo motor responsible for advancing the tape forwards. The RP2040's flash memory is used to store key information for each feeder, including the MPN (Manufacturer Part Number), quantity, and footprint of the components being fed.

## Progress Checklist

1. [X] System Level Block Diagram
2. [X] Feeder Block Diagram
3. [ ] Backplane Block Diagram
4. [X] MVP Feeder Hardware Prototype
5. [ ] Feeder Positioning Accuracy Testing
6. [X] Feeder Lifespan Testing
7. [ ] Neoden 4 Data Packet Reverse Engineering
8. [ ] Mechanical Footprint Design
9. [ ] Feeder PCB Layout
10. [ ] Feeder Schematic
11. [ ] Integrate & Test Feeder
12. [ ] Backplane PCB Layout
13. [ ] Backplane PCB Schematic
14. [ ] System Integration and Testing

## Contributing
Contributions are welcome! Please check the progress checklist above and feel free to open issues or submit pull requests for any ongoing tasks.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

