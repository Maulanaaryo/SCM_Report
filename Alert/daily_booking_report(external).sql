Declare @Office varchar(20)
Declare @Client varchar(20)
Declare @PortOfLoading Varchar(20)
Declare @PortOfDischarge Varchar(20)
Declare @FromDate Varchar(20)
Declare @ToDate Varchar(20)
Declare @JobType Varchar(20)
Declare @ShipmentStatus Varchar(20)
Declare @CustomerId uniqueidentifier
Declare @FromDt DateTime
declare @ToDt DateTime
Declare @ShippingLine varchar(100)
DECLARE @ServiceType uniqueidentifier

SET @PortOfLoading = ''
SET @PortOfDischarge = ''
SET @JobType = 'Export'
SET @ShipmentStatus = ''


SELECT @ServiceType = id from Sys_Service where Code = 'Sea-Freight'


---------------- LOGIC ---------------------------------
If(@FromDate <> '')
	SET @FromDt = Cast(@FromDate as DateTime)
If(@ToDate <> '')
	SET @ToDt = Cast(@ToDate + ' 23:59:59' as DateTime)


declare @ShipperType uniqueidentifier
declare @ConsingeeType uniqueidentifier
Declare @CarrierType uniqueidentifier


select @ShipperType = Id from Sys_PartyTypes where Code = 'Shipper'
select @ConsingeeType = Id from Sys_PartyTypes where Code = 'Consignee'
select @CarrierType = id from Sys_PartyTypes where Code = 'ShippingLine'

CREATE TABLE #SeaJobs
(
	Office VARCHAR(100), ClientName VARCHAR(100), SalesPIC VARCHAR(100), BookingNo VARCHAR(50), BookingDate DateTime,BookingStatus VARCHAR(50),
	JobType VARCHAR(20), JobNo VARCHAR(50), Shipper VARCHAR(100), Consignee VARCHAR(100), 
	JobStatus VARCHAR(20), CreatedBy VARCHAR(50), CreatedOn DateTime,
	ETD DateTime, ETA DateTime, ATD DateTime, ATA DateTime, RSD Datetime,
	Carrier VARCHAR(100), MBL VARCHAR(100), MBLDate DateTime, HBL VARCHAR(100), HBLDate DateTime,
	POLCode VARCHAR(50), POLName VARCHAR(100), PODCode VARCHAR(50), PODName VARCHAR(100),
	PlaceOfReceiptCode VARCHAR(50), PlaceOfReceiptName VARCHAR(100),
	PlaceOfDeliveryCode VARCHAR(50), PlaceOfDeliveryName VARCHAR(100),
	OriginCountry VARCHAR(100), DestinationCountry VARCHAR(100),
	TotalPackages Numeric(26, 5), TotalPackagesUOM VARCHAR(50),
	TotalNetWeight Numeric(26, 5), TotalGrossWeight Numeric(26, 5), TotalChargeableWeight Numeric(26, 5), TotalWeightUOM VARCHAR(50),
	TotalVolume Numeric(26, 5), TotalVolumeUOM VARCHAR(50),
	VesselName VARCHAR(100), VoyageNo VARCHAR(50), VoyageDate DateTime,
	[Open Date CY]VARCHAR(100) ,[Close Date CY] VARCHAR(100),[Internal/External] VARCHAR(100),
	Sequence int,
	ActivityName VARCHAR(50), ActivityETD DateTime, ActivityETA DateTime,
	ActivityATD DateTime, ActivityATA DateTime, ActivityDuration varchar(20), NextActivityGap Varchar(20),
	ActivityUpdatedon DateTime, ActivityUpdateby VARCHAR(50),
	CarrierBookingNo VARCHAR(50)
)

INSERT INTO #SeaJobs
select COff.Code 'Office', Client.Name 'Client', SLPIC.Contact_Email 'SalesPIC', BI.BookingNumber 'BookingNo', BI.BookingDate 'BookingDate',Bi.Status 'BookingStatus', 
BP.Code 'JobType', BP.ProcessNumber 'JobNo', ShipperParty.Name 'Shipper', ConsigneeParty.Name 'Consignee',
BP.Status 'JobStatus', BP.CreatedBy 'JobCreatedBy', BP.CreatedOn 'JobCreatedOn',
BS.ETDDatetime 'ETD', BS.ETADatetime 'ETA', BS.ATDDatetime 'ATD', BS.ATADatetime 'ATA',
convert(varchar(12), dbo.fn_TimeZone(BI.ETDDatetime, BI.ETDTimeZoneId), 106) 'RSD',
ShippingLineParty.Name 'Carrier', BS.WayBillNo 'MAWB', BS.WayBillDate 'MAWBDate', BS.HouseWayBillNo 'HAWB', BS.HouseWayBillDate 'HAWBDate',
PL.Code 'PortOfLoadingCode', PL.Name 'PortOfLoadingName',
PD.Code 'PortOfDischargeCode', PD.Name 'PortOfDischargeName',
POR.Code 'PlaceOfReceiptCode', POR.Name 'PlaceOfReceiptName',
POD.Code 'PlaceOfDeliveryCode', POD.Name 'PlaceOfDeliveryName',
OCountry.Name 'CountryOfOrigin', DCountry.Name 'CountryOfDestination', 
BS.TotalPackages, PackageUOM.Name 'PackageUOM',
BS.NetWeight 'TotalNetWeight', BS.GrossWeight 'TotalGrossWeight', BS.ChargeableWeight 'Total Chargable Weight',
WeightUOM.Code 'TotalWeightUOM', BS.VolumeValue 'TotalVolume', VolumeUOM.Code 'TotalVolumeUOM',
BS.VesselName, BS.VoyageNo, BS.VoyageDateDateTime 'VesselVoyageDate',

-- UserDefined Field
cf.[Open Date CY],cf.[Close Date CY],[Internal-External],
-- ACTIVITY --
Act.SequenceNumber as Sequence,
ACT.Name, ACT.ETDDatetime 'ActivityETD', ACT.ETADatetime 'ActivityETA', 
	ACT.ATDDatetime 'ActivityATD', ACT.ATADatetime 'ActivityATA', ACT.Duration, ACT.NextActivityGap,
	act.LastModifiedOn,act.LastModifiedBy,
	Bs.CarrierBookingReferenceNumber 'CarrierBookingNo'


from Bkg_BookingInfo BI WITH (NOLOCK) 
	left join Bkg_BookingProcess BP WITH (NOLOCK) on BP.BookingInfoId = bi.id
	LEFT JOIN cust_office cOff WITH (NOLOCK) ON cOff.Id = BP.OwnerOfficeId AND cOff.IsActive = 1 AND cOff.IsDeleted = 0
	LEFT JOIN Sys_TransportationMode TSMode WITH (NOLOCK) ON BP.TransportationModeId = TSMode.Id AND tsMode.IsActive = 1
	Left JOIN Bkg_BookingService BS WITH (NOLOCK) ON BP.BookingServiceId = bs.Id AND bs.IsDeleted = 0 AND bs.IsActive = 1
		LEFT JOIN Bkg_BookingParty ShipperParty ON BS.Id = ShipperParty.BookingServiceId 
			AND ShipperParty.PartyTypeId = @ShipperType and ShipperParty.IsDeleted = 0
		LEFT JOIN Bkg_BookingParty ConsigneeParty ON BS.Id = ConsigneeParty.BookingServiceId 
			AND ConsigneeParty.PartyTypeId = @ConsingeeType and ConsigneeParty.IsDeleted = 0
		LEFT JOIN Bkg_BookingParty ShippingLineParty ON BS.Id = ShippingLineParty.BookingServiceId 
			AND ShippingLineParty.PartyTypeId = @CarrierType and ShippingLineParty.IsDeleted = 0
		LEFT JOIN Cust_Location PL WITH (NOLOCK) ON PL.ID = BS.portofLoadingId
		LEFT JOIN Cust_Location PD WITH (NOLOCK) ON PD.ID = BS.PortOfDischargeId
		LEFT JOIN Cust_Location POR WITH (NOLOCK) ON POR.ID = BS.portofLoadingId
		LEFT JOIN Cust_Location POD WITH (NOLOCK) ON POD.ID = BS.PortOfDischargeId
		LEFT JOIN Sys_UOM WeightUOM WITH (NOLOCK) ON WeightUOM.ID = BS.[WeightUOMId]
		LEFT JOIN Sys_UOM VolumeUOM WITH (NOLOCK) ON VolumeUOM.ID = BS.VolumeUOMId
		LEFT JOIN Cust_Country OCountry WITH (NOLOCK) on BS.CountryOfOriginId = OCountry.Id
		LEFT JOIN Cust_Country DCountry WITH (NOLOCK) on BS.CountryOfDestinationId = DCountry.Id
   		LEFT JOIN Sys_UOM PackageUOM WITH (NOLOCK) ON BS.PackageUOMId = PackageUOM.Id AND PackageUOM.UOMType = 'Packages'
	
		LEFT JOIN cust_clients Client WITH (NOLOCK) ON BI.ClientId = Client.Id AND client.IsActive = 1 AND Client.IsDeleted = 0
	LEFT JOIN Bkg_BookingActivity ACT ON ACT.BookingProcessId = BP.Id AND ACT.IsDeleted = 0
	LEFT JOIN Sys_Process SYSPROC WITH(NOLOCK) ON SYSPROC.Id = BP.ProcessId
	--Custom fields
Left join (select * from (
								Select Processnumber,Bi.bookingnumber,EntityId,Entity,	DisplayName 'UDF', 	ef.FieldValue 'Value'
								from Cust_ExtensionFields EF left join Cust_ExtensionFieldMetaData EFMD
								on EFMD.Id = ef.ExtensionFieldMetaDataId Left join  Bkg_BookingProcess BP on bp.id = ef.EntityId left join Bkg_BookingInfo BI on BI.id = bp.BookingInfoId
								where bi.BookingNumber is not null and Entity = 'Sea'
								) src
								pivot(	min ([Value])	for [UDF] in ([Open Date CY],[Close Date CY])) piv 	
				) as CF 
on CF.BookingNumber = bi.BookingNumber and cf.ProcessNumber = bp.ProcessNumber

Left join (select * from (
		Select Bi.bookingnumber,EntityId,Entity,	DisplayName 'UDF', 	ef.FieldValue 'Value'
		from Cust_ExtensionFields EF 
		left join Cust_ExtensionFieldMetaData EFMD	on EFMD.Id = ef.ExtensionFieldMetaDataId 
		left join Bkg_BookingInfo BI on BI.id = ef.EntityId
		where bi.BookingNumber is not null 
		) src
		pivot(	min ([Value])	for [UDF] in ([Open Date CY],[Close Date CY],[Internal-External])) piv 	
		) as BCF 
on BCF.BookingNumber = bi.BookingNumber 

-- Sales PIC
left join (Select Bi.Id,  cr.Contact_PersonName_FirstName + ' ' + cr.Contact_PersonName_LastName as Contact_Email from 
Bkg_BookingTeam BT with(nolock) 
inner join Bkg_BookingInfo BI with(nolock) on BI.id = bt.BookingInfoId and bt.IsDeleted = 0  
inner join Cust_ResOfficeResFuncMap RORF with(nolock) on RORF.Id = bt.ResOfficeResFuncMapId
inner join Cust_Resource CR with(nolock) on cr.Id = bt.ResourceId
inner join Sys_ResourceFunction RF with(nolock) on rf.Id = rorf.ResourceFunctionId and rf.id = '457d6ee0-e130-4948-8359-3a7c3ca38a51') as SLPIC
on SLPIC.id = bi.Id

	WHERE isnull(BP.Status,'') not in ('Completed','Cancelled','Closed') and ShipperParty.Name is not null
		AND cOff.Code = 'JKT'
		and bi.Status = 'Confirmed'
		--AND (@Client = '' OR Client.Code = @Client)
		--AND (@JobType = '' OR BP.Code = @JobType)
		--AND (BI.BookingDate BETWEEN @FromDt AND @ToDt)
		--AND (isNull(@ShippingLine, '') = '' OR ShippingLineParty.Name like '%' + isNull(@ShippingLine, '') + '%')

--Select * from #SeaJobs where BookingNo ='JKTUATBKG2300097' order by BookingNo,JobNo,Sequence 
Select Distinct SJ.MBL,SJ.MBLDate,sj.ClientName,SJ.SalesPIC,SJ.BookingDate,SJ.Shipper,sj.Consignee,
SJ.POLCode,SJ.POLName,SJ.PODCode ,SJ.PODName, 
SJ.PlaceOfReceiptCode , SJ.PlaceOfReceiptName ,
	SJ.PlaceOfDeliveryCode , SJ.PlaceOfDeliveryName ,
	SJ.JobStatus,
SJ.ETD , SJ.ETA , SJ.ATD , SJ.ATA , SJ.RSD ,
SJ.[Open Date CY],SJ.[Close Date CY],sj.[Internal/External],Cast(Round(SJ.Sequence,0) as varchar(20)) as StepNo,
SJ.ActivityName LastActivityUpdated,SJ.ActivityATD as LastActivityDate, SJ.ActivityUpdatedon,SJ.ActivityUpdateby,SJNA.ActivityName NextActivity,
SJNA.ActivityETA NextActivityDate,
sj.Office,SJ.BookingNo,sj.bookingstatus,SJ.JobNo,sj.Carrier,sj.CarrierBookingNo,sj.JobType
 Into #BookingMonitor from #SeaJobs SJ 
Inner join  
(Select bookingno,jobno,Max(Sequence) as LastActivity from #SeaJobs 
where ActivityATD is not null 
group by bookingno,jobno) maxAct
on maxact.BookingNo = sj.BookingNo and maxact.JobNo = sj.JobNo and maxact.LastActivity = sj.Sequence
Left join  #SeaJobs SJNA
on maxact.BookingNo = SJNA.BookingNo and maxact.JobNo = SJNA.JobNo and maxact.LastActivity +1  = SJNA.Sequence


Insert into #BookingMonitor
select Distinct SJ.MBL,SJ.MBLDate,sj.ClientName,SJ.SalesPIC,SJ.BookingDate,SJ.Shipper,sj.Consignee,
SJ.POLCode,SJ.POLName,SJ.PODCode ,SJ.PODName, 
SJ.PlaceOfReceiptCode , SJ.PlaceOfReceiptName ,
	SJ.PlaceOfDeliveryCode , SJ.PlaceOfDeliveryName ,
	SJ.JobStatus,
SJ.ETD , SJ.ETA , SJ.ATD , SJ.ATA , SJ.RSD ,SJ.[Open Date CY],SJ.[Close Date CY],sj.[Internal/External],'0' as StepNo,
'Not Started' LastActivityUpdated,Null as LastActivityDate, Null,Null,
SJ.ActivityName  NextActivity,
sj.ActivityETA  NextActivityDate,
sj.Office,SJ.BookingNo,sj.bookingstatus,SJ.JobNo,
sj.Carrier,sj.CarrierBookingNo ,sj.JobType from #SeaJobs SJ
left join #BookingMonitor BM on BM.BookingNo = SJ.BookingNo and BM.JobNo = SJ.JobNo
where sj.Sequence = 1 and BM.BookingNo is null 


update BM set StepNo = StepNo + '/' + MaxSeq 
from #BookingMonitor as BM, (Select BookingNo,JobNo,Cast(Max(Round(Sequence,0)) as varchar(20)) as MaxSeq from #SeaJobs group by BookingNo,JobNo) as Maxs
where Maxs.BookingNo = BM.BookingNo and Maxs.JobNo = BM.JobNo 


update #BookingMonitor set ActivityUpdateby = Contact_PersonName_FirstName
from (select Loginid,Contact_PersonName_FirstName +' ' +Contact_PersonName_LastName as Contact_PersonName_FirstName from Cust_Users cu with(nolock)
left join Cust_Resource CR with(nolock) on cr.UserId  = cu.Id) as UserDetails
where #BookingMonitor.ActivityUpdateby = LoginId


-- Select statement
select MBL,CarrierBookingNo,BookingNo,JobNo,JobType,JobStatus,ClientName,Carrier,
SalesPIC,Shipper,Consignee,POLName,PODName, 
PlaceOfReceiptName ,PlaceOfDeliveryName ,
ETD , ETA , ATD , ATA , RSD ,StepNo,
LastActivityUpdated,LastActivityDate, ActivityUpdatedon,ActivityUpdateby,NextActivity,
NextActivityDate,Bookingstatus
 from #BookingMonitor 
 where [Internal/External] = 'External'



Drop Table #BookingMonitor
DROP TABLE #SeaJobs