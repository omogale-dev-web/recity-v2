import {z} from 'zod';
export const observationSchema=z.object({object:z.string().max(120),material:z.string().max(120),category:z.enum(['recyclable','organic','electronic','sanitary','hazardous','construction','bulky','animal_remains','mixed','unknown','not_waste']),certainty:z.enum(['clear','uncertain']),condition:z.string().max(300),hazards:z.array(z.enum(['chemical','sharp','biological','battery','fire','unknown'])).max(6),reason:z.string().max(600),questions:z.array(z.string().max(180)).max(3),reuse_candidate:z.boolean()});
export type Observation=z.infer<typeof observationSchema>;
export function decide(o:Observation){
 const special=['hazardous','animal_remains','sanitary','electronic'].includes(o.category);
 const knownHazard=o.hazards.some(h=>h!=='unknown');
 const uncertain=o.certainty==='uncertain'||o.category==='unknown'||o.hazards.includes('unknown');
 // Policy points are illustrative screening priorities, not calibrated probability or physical measurement.
 let score:number|null=null;
 if(o.category!=='not_waste'&&!uncertain){score=special?85:knownHazard?70:o.category==='mixed'?55:o.category==='organic'?35:15;}
 return {score,label:score===null?'Unable to assess':score>=70?'High':score>=30?'Moderate':'Low',policyVersion:'screening-0.1-unvalidated',reuseAllowed:o.reuse_candidate&&!special&&!knownHazard&&!uncertain&&o.category!=='not_waste'&&o.category!=='mixed',route:o.category==='not_waste'?'No clear discarded waste. Confirm whether this item is being discarded.':special||knownHazard?'Request an appropriate specialist collection service.':uncertain?'Provide more information or submit a report for review.':o.category==='organic'?'Assess suitability for composting or request organic-waste collection.':'Consider suitable reuse or local recycling.'};
}
