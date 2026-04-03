# Heat Rejection System Modelling & Optimisation (Rolls-Royce Project)

## Overview
This project formed part of a multi-university engineering programme run in collaboration with Rolls-Royce, involving more than 20 teams from universities including Imperial, UCL, Oxford, and Cambridge. Our team placed 3rd overall.

My subgroup worked on the independent water heat rejection stage of the wider system. The challenge was to design a heat rejection solution for a scaled high-temperature gas reactor configuration operating in water-scarce regions, where conventional water-intensive cooling methods were unsuitable. The system therefore had to reject approximately 147.7 MWth while balancing three competing objectives: low parasitic load, compact footprint, and operational safety.

## My Role
I worked on the heat rejection half of the project, where my contribution combined engineering research, calculation work, and computational modelling.

A significant part of my role involved researching existing and emerging water-independent heat rejection methods and helping evaluate their suitability for our use case. This included looking into air-cooled condensers, natural draft dry cooling, porous metal-based concepts, and radiative cooling approaches, with attention to trade-offs in parasitic load, footprint, feasibility, and practical deployment constraints. The final design process used these comparisons to guide concept selection. 

I also handled calculations related to the electrical and parasitic load across the heat rejection system, and contributed to implementing engineering equations in code so that performance could be evaluated quantitatively rather than discussed only at a conceptual level. In addition, I developed an optimisation model for an earlier stacked-pipe configuration, where pipe count, diameter, frictional losses, and flow behaviour had to be balanced within a fixed geometric constraint.

## Design Development and Research
Before arriving at the final concept, we reviewed several possible water-independent heat rejection methods. The report compares air-cooled condensers, natural draft dry cooling towers, porous metal fins, and radiative cooling panels, each with different strengths and weaknesses in footprint, heat transfer capability, and parasitic load. For example, air-cooled condensers were well established but large and relatively limited by air-side heat transfer; radiative cooling was promising in theory but heavily wind-dependent and required a very large footprint; porous metal concepts offered compactness and strong heat transfer but needed further validation. 

To formalise this decision, the team used a weighted Pugh matrix comparing candidate concepts against criteria including parasitic load, heat transfer coefficient, footprint, safety, maintenance, and cost. In that assessment, the porous cube concept achieved the highest total score, largely because its high effective surface area offered strong heat transfer with a reduced footprint.

## Final Design
The final design adopted a three-stage heat rejection architecture:

1. **Helium-on-water heat rejection** using a shell-and-tube heat exchanger  
2. **Steam-on-water heat rejection** using a porous metal cube as the heat transfer medium  
3. **Steam-on-air heat rejection** using air-cooled condenser modules

This architecture was chosen because it addressed the safety requirement of separating the radioactive helium loop while also reducing parasitic load and footprint. The porous receiver increased effective condensation area, while the thermosyphon-based arrangement reduced the need for additional pumping in the steam-side loop through passive two-phase transport. The slides describe this as a scalable concept in which system scaling is linked to thermosyphon count, with operating cost driven primarily by fan power in the dry coolers. 

## My Technical Contribution

### 1. Electrical / Parasitic Load Calculations
One of my key responsibilities was working through the electrical load implications of the heat rejection system. A major part of the engineering challenge was that the cooling solution had to be water-independent, which meant auxiliary loads could not be ignored.

In the final model, the condensate loop pump was analysed using Darcy–Weisbach-based pipe loss calculations, with assumptions including a 30 m pipe length, 3 m/s flow velocity, 0.045 mm pipe roughness, and a pump efficiency of 0.75. This gave a calculated pump electrical power of 3.51 kW. 

The dry cooler side was modelled using manufacturer data for commercial modules, including surface area, airflow, and dimensions. From that, the team calculated effective per-module heat rejection capacity, required module count, total airflow, and estimated fan power. These contributions fed directly into the total parasitic load of the heat rejection system. 

The final baseline result for the model was:
- **Heat rejected:** 147.7 MWth  
- **Total parasitic load:** 3.17 MW  
- **Parasitic load per MWth rejected:** 21.5 kW  
- **Dry cooler modules required:** 1700  
- **Estimated footprint:** 60,214 m²

I was involved in the calculation and implementation work behind these load estimates, helping ensure that the design was judged not only by thermal feasibility, but also by its electrical penalty and practical efficiency.

### 2. Pipe Configuration Optimisation Code
Alongside the final model, I developed code for an earlier stacked-pipe heat exchanger concept that explored how pipe count affected efficiency within a fixed available volume.

The key engineering trade-off was that increasing the number of pipes increased potential heat transfer area, but also reduced individual pipe diameter because all pipes had to fit inside the same constrained geometry. Smaller diameters then changed flow behaviour and increased frictional losses. My optimisation code took in parameters such as pipe length, friction-related factors, and flow assumptions, and evaluated the resulting configurations to determine a more efficient pipe quantity for the design.

This was useful because it converted a geometric design question into a computational optimisation problem, forcing the design to account for both thermal and fluid-dynamic trade-offs rather than selecting a pipe arrangement by intuition alone.

### 3. Model Building and Formula Implementation
I also helped with the coding side of the final heat rejection model by writing and implementing the engineering calculations used in the wider computational workflow.

From the report, the model included:
- enthalpy-balance-based mass flow calculations
- steam-side condensation modelling using Nusselt film condensation ideas
- porous foam effective area and efficiency calculations
- thermosyphon transport limit checks
- condensate drainage checks comparing hydrostatic head against pressure losses
- dry cooler sizing and UA verification
- pump and fan parasitic load estimation 

My contribution was helping translate these kinds of calculations and formulae into usable code so the model could be iterated and used for design decisions, rather than remaining as isolated hand calculations.

## Iteration and Validation
The project was iterative rather than fixed from the start. The slides show that the heat rejection load changed several times as parameters were exchanged with the HTGR subteam: an early literature estimate assumed roughly 3% of ~200 MW for air-cooled condensers, later iterations used 78 MW, then 205 MW when returning to helium gas heat rejection and including pump power, before settling on the updated 147.7 MW value from the reactor model. 

The final result was then compared against industry expectations. The report notes that water-independent air-cooled heat rejection systems typically show parasitic loads in the range of 4–6% of power output, while the model predicted 21.5 kW per MWth rejected, approximately 2.15% of power output, which was considered to be of the same order of magnitude and therefore a promising result.

## Computational Modelling

A key part of my contribution involved implementing a computational model to simulate and evaluate the performance of the heat rejection system under varying operating conditions.

The model:

- Simulates system behaviour across a range of heat loads (Q_total)
- Performs a parametric sweep to analyse system sensitivity
- Evaluates performance metrics including:
  - number of cooling modules required
  - parasitic fan power
  - airflow requirements
  - thermal performance (UA margin, outlet temperatures)

The model incorporates engineering calculations across multiple domains, including:
- thermodynamics (enthalpy, phase change, heat transfer)
- fluid dynamics (flow rates, friction losses, pressure drop)
- heat exchanger design (LMTD, UA analysis)
- system-level optimisation and constraints

It also includes:

- iterative optimisation to determine required system size
- constraint-based stopping conditions (e.g. parasitic load limits)
- validation checks against realistic operating ranges

The implementation is structured as a modular MATLAB model, allowing different subsystems (air cooling, thermosyphons, condensation, flow) to be analysed and modified independently.

See `/code/thermosyphon_model.m` for full implementation.

## Outcome
The final concept used porous metal cubes with integrated thermosyphons and dry coolers to reduce footprint and pump work in the intermediate safety loops. The design was judged promising because it achieved a reasonable parasitic load while maintaining the safety separation required for the helium loop. The report concludes that the concept optimised footprint and parasitic load by using porous metal cubes with integrated thermosyphons, and our team’s work placed 3rd overall in a field of 20+ teams across multiple universities (being UCL, Imperial, Oxford and Cambridge).

## What I Learned
This project strengthened my ability to:
- translate engineering equations into working computational models
- evaluate real-world trade-offs between efficiency, parasitic load, footprint, and feasibility
- use calculation and modelling work to support design choices
- combine literature research with implementation and quantitative analysis
- work effectively in a technically competitive team environment
