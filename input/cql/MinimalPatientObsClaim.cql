library MinimalPatientObsClaim version '1.0.1'

using FHIR version '4.0.1'
include FHIRHelpers version '4.4.000' called FHIRHelpers
include FHIRCommon version '4.1.000' called FHIRCommon

/* Measurement Period: 2025-01-01T00:00:00 through 2025-12-31 */
//parameter "Measurement Period" Interval<Date>
//  default Interval[@2025-01-01, @2026-01-01)
parameter "Measurement Period" Interval<DateTime>
  default Interval[@2025-01-01T00:00:00.0, @2026-01-01T00:00:00.0)

context Patient

define "Patient Resource":
  Patient

define "Get Observation":
  [Observation] O
    where O.effective during "Measurement Period"

define "Member Claims2":
[Claim] C
where exists C.item CItem
//where FHIRBase."Normalize Date Interval" ( CItem.serviced ) overlaps "Measurement Period".

define "Member Claims1":
  [Claim] C
    where exists (C.item I where I.serviced overlaps "Measurement Period")

define "Member Claims":
[Claim] C
where exists C.item CItem
where CItem.serviced  overlaps day of "Measurement Period"

define "Member Claims3":
  [Claim] C where exists (C.item I where I.serviced is not null)

define "Member Claims4":
  [Claim] C
    return {
      claimId: C.id,
      items: 
        C.item I 
          return { 
            serviced: I.serviced, 
            servicedInterval: FHIRCommon.ToInterval(I.serviced),
            measurementPeriod: "Measurement Period", 
            overlaps: FHIRCommon.ToInterval(I.serviced) overlaps day of "Measurement Period" 
          }
    }