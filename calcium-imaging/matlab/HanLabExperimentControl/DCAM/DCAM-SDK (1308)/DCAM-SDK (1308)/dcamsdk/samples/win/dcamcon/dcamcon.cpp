#include "stdafx.h"

#define NUMBER_OF_FRAMES						4			// The number of frames to be captured.
#define USE_DCAM_BASIC_EXPOSURETIME_SET			TRUE		// If set to FALSE, this program will use the dcam_extended() function to control exposure time.
#define USE_DCAM_API_MEMORY_MANAGEMENT			TRUE		// If set to FALSE, this program owns the recording memory buffer.

int main(int argc, char* argv[])
{
	long nCameras = 0;

	if (dcam_init( NULL, &nCameras, NULL) && nCameras)
	{
		HDCAM	hDCAM = NULL;
		long	CameraIndex = 0;
		char	CameraName[64];
		char	CameraID[64];
		long	i;
			
		if (nCameras > 1)
		{
			for (i = 0;i < nCameras;i++)
			{
				if (dcam_getmodelinfo(i,DCAM_IDSTR_MODEL,CameraName,sizeof(CameraName)))
				{
					if (dcam_getmodelinfo(i,DCAM_IDSTR_CAMERAID,CameraID,sizeof(CameraID)))
						printf ("%ld - %s (%s)\n",i,CameraName,CameraID);
					else
						printf ("%ld - %s\n",i,CameraName);
				}
			}

			CameraIndex = -1;
			while ((CameraIndex < 0) || (CameraIndex >= nCameras))
			{
				printf("\n\nEnter the index of the camera you want to use.\n");
				scanf_s( "%ld", &CameraIndex );
			}

			getchar();
		}
		
		if (dcam_open( &hDCAM, CameraIndex, NULL) && hDCAM)
		{
			if (dcam_getstring(hDCAM,DCAM_IDSTR_MODEL,CameraName,sizeof(CameraName)))
			{
				_DWORD CameraCapability = 0;

				if (dcam_getstring(hDCAM,DCAM_IDSTR_CAMERAID,CameraID,sizeof(CameraID)))
					printf ("\n\nThe camera model being used is the %s (%s)\n\n",CameraName,CameraID);
				else
					printf ("\n\nThe camera model being used is the %s\n\n",CameraName);

				if (dcam_getcapability(hDCAM,&CameraCapability,DCAM_QUERYCAPABILITY_FUNCTIONS))
				{
					if (!USE_DCAM_API_MEMORY_MANAGEMENT && !(CameraCapability & DCAM_CAPABILITY_USERMEMORY))
						printf ("\n\nUser Memory Management is not supported by this camera's module!\n\n");
					else
					{
						DCAM_SIZE FinalImageSize;

						// ScanMode Inquiry Structure
						DCAM_PARAM_SCANMODE_INQ ScanModeInquiry;

						// ScanMode Set/Get Structure
						DCAM_PARAM_SCANMODE ScanMode;

						// SubArray Inquiry Structure
						DCAM_PARAM_SUBARRAY_INQ SubArrayInquiry;

						// SubArray Set/Get Structure
						DCAM_PARAM_SUBARRAY SubArrayValue;

						// Frame Readout Time Get Structure
						DCAM_PARAM_FRAME_READOUT_TIME_INQ FrameReadoutTimeInq;

						// Feature Inquiry Structure
						DCAM_PARAM_FEATURE_INQ FeatureInquiry;

						// Feature Set/Get Structure
						DCAM_PARAM_FEATURE FeatureValue;
						
						// Default exposure time is 1.0 second
						double lfCurrentExposureTime = 1.0;
						float fNewExposureTimeValue = 1.0f;
						
						_DWORD BinningCaps;

						// I am only interested in Binning support, so mask out the other capabilities
						CameraCapability &= 0x000000FE;
						BinningCaps = CameraCapability;
						
						if (BinningCaps)
						{
							BOOL bBinningOK = FALSE;
							long Binning = 0;
							printf ("1 x 1 Binning\n");
							
							while (BinningCaps)
							{
								if (BinningCaps & DCAM_CAPABILITY_BINNING2)
								{
									printf ("2 x 2 Binning\n");
									BinningCaps &= ~DCAM_CAPABILITY_BINNING2;
								}
								else
								{
									if (BinningCaps & DCAM_CAPABILITY_BINNING4)
									{
										printf ("4 x 4 Binning\n");
										BinningCaps &= ~DCAM_CAPABILITY_BINNING4;
									}
									else
									{
										if (BinningCaps & DCAM_CAPABILITY_BINNING8)
										{
											printf ("8 x 8 Binning\n");
											BinningCaps &= ~DCAM_CAPABILITY_BINNING8;
										}
										else
										{
											if (BinningCaps & DCAM_CAPABILITY_BINNING16)
											{
												printf ("16 x 16 Binning\n");
												BinningCaps &= ~DCAM_CAPABILITY_BINNING16;
											}
											else
											{
												if (BinningCaps & DCAM_CAPABILITY_BINNING32)
												{
													printf ("32 x 32 Binning\n");
													BinningCaps &= ~DCAM_CAPABILITY_BINNING32;
												}
											}
										}
									}
								}
							}

							// add 1x1 binning to the test
							CameraCapability |= 1;
							while (!bBinningOK)
							{
								printf("\n\nEnter the camera's binning mode you want to use.\n");
								scanf_s( "%ld", &Binning );
								if (Binning == 1)
									bBinningOK = TRUE;
								else
								{
									if ((Binning >= 2) && ((Binning%2) == 0) || (Binning & ~CameraCapability))
										bBinningOK = TRUE;
								}
							}

							getchar();

							if (dcam_setbinning(hDCAM,Binning))
								printf("\n\nThe camera's binning mode is %ld\n\n\n",Binning);
							else
								printf("\n\nAn error occurred trying to set the camera's binning mode.");
						}

						// *****************************
						// Query Scan Mode feature
						// *****************************
						memset( &ScanModeInquiry, 0, sizeof(DCAM_PARAM_SCANMODE_INQ));
						ScanModeInquiry.hdr.cbSize = sizeof(DCAM_PARAM_SCANMODE_INQ);
						ScanModeInquiry.hdr.id = DCAM_IDPARAM_SCANMODE_INQ;
						
						if (dcam_extended(hDCAM,DCAM_IDMSG_GETPARAM,&ScanModeInquiry,sizeof(DCAM_PARAM_SCANMODE_INQ)))
						{
							// If the maximum Scan Mode is greater than 1, then we can select a scan mode (one based index)
							if (ScanModeInquiry.speedmax > 1)
							{
								memset( &ScanMode, 0, sizeof(DCAM_PARAM_SCANMODE));
								ScanMode.hdr.cbSize = sizeof(DCAM_PARAM_SCANMODE);
								ScanMode.hdr.id = DCAM_IDPARAM_SCANMODE;

								while ((ScanMode.speed < 1) || (ScanMode.speed > ScanModeInquiry.speedmax))
								{
									printf( "\n\nEnter a valid Scan Mode between 1 and %ld.\n",ScanModeInquiry.speedmax);
									scanf_s( "%ld", &ScanMode.speed );
								}

								getchar();

								// set new Scan Mode setting
								if (dcam_extended(hDCAM,DCAM_IDMSG_SETGETPARAM,&ScanMode,sizeof(DCAM_PARAM_SCANMODE)))
									printf("\n\nThe camera's Scan Mode setting is %ld.\n\n\n",ScanMode.speed);
								else
									printf("\n\nAn error occurred trying to set the new Scan Mode to the camera.");
							}
						}

						// *****************************
						// Query SubArray feature
						// *****************************
						memset( &SubArrayInquiry, 0, sizeof(DCAM_PARAM_SUBARRAY_INQ));
						SubArrayInquiry.hdr.cbSize = sizeof(DCAM_PARAM_SUBARRAY_INQ);
						SubArrayInquiry.hdr.id = DCAM_IDPARAM_SUBARRAY_INQ;
						
						if (dcam_extended(hDCAM,DCAM_IDMSG_GETPARAM,&SubArrayInquiry,sizeof(DCAM_PARAM_SUBARRAY_INQ)))
						{
							long SubArrayHorizMax,SubArrayVertMax;
							
							long NewHorizOffsetValue = -1;
							long NewHorizWidthValue = -1;
							long NewVertOffsetValue = -1;
							long NewVertHeightValue = -1;

							// If the hunit and hmax are equal, then we do not support horizontal subarray, so the default is the full, maximum size.
							if (SubArrayInquiry.hunit == SubArrayInquiry.hmax)
							{
								NewHorizOffsetValue = 0;
								NewHorizWidthValue = SubArrayInquiry.hmax;
							}
							else
							{
								while ((NewHorizOffsetValue % SubArrayInquiry.hposunit) || (NewHorizOffsetValue < 0) || (NewHorizOffsetValue > (SubArrayInquiry.hmax - SubArrayInquiry.hunit)))
								{
									printf( "\n\nEnter a valid SubArray Horizontal Offset value between 0 and %ld in steps of %ld.\n",SubArrayInquiry.hmax - SubArrayInquiry.hunit,SubArrayInquiry.hposunit);
									scanf_s( "%ld", &NewHorizOffsetValue );
								}

								getchar();

								SubArrayHorizMax = ((SubArrayInquiry.hmax - NewHorizOffsetValue) / SubArrayInquiry.hunit) * SubArrayInquiry.hunit;

								if (SubArrayHorizMax <= SubArrayInquiry.hunit)
									NewHorizWidthValue = SubArrayInquiry.hunit;
								else
								{
									while ((NewHorizWidthValue % SubArrayInquiry.hunit) || (NewHorizWidthValue < SubArrayInquiry.hunit) || (NewHorizWidthValue > SubArrayHorizMax))
									{
										printf( "\n\nEnter a valid SubArray Horizontal Width value between %ld and %ld in steps of %ld.\n",SubArrayInquiry.hunit,SubArrayHorizMax,SubArrayInquiry.hunit);
										scanf_s( "%ld", &NewHorizWidthValue );
									}

									getchar();
								}
							}

							// If the vunit and vmax are equal, then we do not support vertical subarray, so the default is the full, maximum size.
							if (SubArrayInquiry.vunit == SubArrayInquiry.vmax)
							{
								NewVertOffsetValue = 0;
								NewVertHeightValue = SubArrayInquiry.vmax;
							}
							else
							{
								while ((NewVertOffsetValue % SubArrayInquiry.vposunit) || (NewVertOffsetValue < 0) || (NewVertOffsetValue > (SubArrayInquiry.vmax -  SubArrayInquiry.vunit)))
								{
									printf( "\n\nEnter a valid SubArray Vertical Offset value between 0 and %ld in steps of %ld.\n",SubArrayInquiry.vmax -  SubArrayInquiry.vunit,SubArrayInquiry.vposunit);
									scanf_s( "%ld", &NewVertOffsetValue );
								}

								getchar();

								SubArrayVertMax = ((SubArrayInquiry.vmax - NewVertOffsetValue) / SubArrayInquiry.vunit) * SubArrayInquiry.vunit;

								if (SubArrayVertMax <= SubArrayInquiry.vunit)
									NewVertHeightValue = SubArrayInquiry.vunit;
								else
								{
									while ((NewVertHeightValue % SubArrayInquiry.vunit) || (NewVertHeightValue < SubArrayInquiry.vunit) || (NewVertHeightValue > SubArrayVertMax))
									{
										printf( "\n\nEnter a valid SubArray Vertical Height value between %ld and %ld in steps of %ld.\n",SubArrayInquiry.vunit,SubArrayVertMax,SubArrayInquiry.vunit);
										scanf_s( "%ld", &NewVertHeightValue );
									}

									getchar();
								}
							}

							// If horizontal or vertical subarray is supported, set the newly requested transfer size.
							if ((SubArrayInquiry.hunit != SubArrayInquiry.hmax) || (SubArrayInquiry.vunit != SubArrayInquiry.vmax))
							{
								memset( &SubArrayValue, 0, sizeof(DCAM_PARAM_SUBARRAY));
								SubArrayValue.hdr.cbSize = sizeof(DCAM_PARAM_SUBARRAY);
								SubArrayValue.hdr.id = DCAM_IDPARAM_SUBARRAY;

								// set new SubArray settings
								SubArrayValue.hpos = NewHorizOffsetValue;
								SubArrayValue.hsize = NewHorizWidthValue;
								SubArrayValue.vpos = NewVertOffsetValue;
								SubArrayValue.vsize = NewVertHeightValue;
								if (dcam_extended(hDCAM,DCAM_IDMSG_SETGETPARAM,&SubArrayValue,sizeof(DCAM_PARAM_SUBARRAY)))
									printf("\n\nThe image SubArray region settings are\n\nSubArray Horizontal Offset = %ld\nSubArray Horizontal Width = %ld\nSubArray Vertical Offset = %ld\nSubArray Vertical Height = %ld\n\n\n",SubArrayValue.hpos,SubArrayValue.hsize,SubArrayValue.vpos,SubArrayValue.vsize);
								else
									printf("\n\nAn error occurred trying to set the new SubArray region to the camera.");
							}
						}

						// *****************************
						// Query Frame Readout Time
						// *****************************
						memset( &FrameReadoutTimeInq, 0, sizeof(DCAM_PARAM_FRAME_READOUT_TIME_INQ));
						FrameReadoutTimeInq.hdr.cbSize = sizeof(DCAM_PARAM_FRAME_READOUT_TIME_INQ);
						FrameReadoutTimeInq.hdr.id = DCAM_IDPARAM_FRAME_READOUT_TIME_INQ;
						
						if (dcam_extended(hDCAM,DCAM_IDMSG_GETPARAM,&FrameReadoutTimeInq,sizeof(DCAM_PARAM_FRAME_READOUT_TIME_INQ)))
							printf("\n\nThe current frame readout time is %f seconds.\n\n\n",FrameReadoutTimeInq.framereadouttime);
						else
							FrameReadoutTimeInq.framereadouttime = 0.5f;	// This value is used for dcam_wait() timeout value. Default will be 5.0 seconds.
																			// ** Note: This is just a cushion for very slow frame rate cameras! **
						
						// *****************************
						// Query Gain/Contrast feature
						// *****************************
						memset( &FeatureInquiry, 0, sizeof(DCAM_PARAM_FEATURE_INQ));
						FeatureInquiry.hdr.cbSize = sizeof(DCAM_PARAM_FEATURE_INQ);
						FeatureInquiry.hdr.id = DCAM_IDPARAM_FEATURE_INQ;
						
						memset( &FeatureValue, 0, sizeof(DCAM_PARAM_FEATURE));
						FeatureValue.hdr.cbSize = sizeof(DCAM_PARAM_FEATURE);
						FeatureValue.hdr.id = DCAM_IDPARAM_FEATURE;

						FeatureInquiry.featureid = FeatureValue.featureid = DCAM_IDFEATURE_GAIN;	// same as DCAM_IDFEATURE_CONTRAST
						if (dcam_extended(hDCAM,DCAM_IDMSG_GETPARAM,&FeatureInquiry,sizeof(DCAM_PARAM_FEATURE_INQ)))
						{
							float fNewGainValue = -65536.0;

							// get the current Gain/Contrast feature value
							if (dcam_extended(hDCAM,DCAM_IDMSG_GETPARAM,&FeatureValue,sizeof(DCAM_PARAM_FEATURE)))
							{
								if (FeatureInquiry.units[0])
									printf("\n\n\nThe current Gain/Contrast value is %f %s.",FeatureValue.featurevalue,FeatureInquiry.units);
								else
									printf("\n\n\nThe current Gain/Contrast value is %ld.",(long)FeatureValue.featurevalue);
							}
							else
								printf("\n\n\nAn error occurred trying to get the Gain/Contrast value of the camera.");

							// check if we can set this feature
							if (FeatureInquiry.step)
							{
								// check to see if this feature is relative or absolute with defined units
								if (FeatureInquiry.units[0])
								{
									// it is absolute with defined units
									while ((fNewGainValue < FeatureInquiry.min) || (fNewGainValue > FeatureInquiry.max))
									{
										printf( "\n\nEnter a valid Gain/Contrast value between %lf %s and %lf %s\n",(double)FeatureInquiry.min,FeatureInquiry.units,(double)FeatureInquiry.max,FeatureInquiry.units);
										scanf_s( "%f", &fNewGainValue );
									}

									// round down to the nearest valid feature value
									fNewGainValue /= FeatureInquiry.step;
									fNewGainValue *= FeatureInquiry.step;

									getchar();
								}
								else
								{
									// it is relative only
									long NewGainValue = -65536;
									long FeatureStep = (long)FeatureInquiry.step;
									long FeatureMin = (long)FeatureInquiry.min;
									long FeatureMax = (long)FeatureInquiry.max;
									while ((NewGainValue % FeatureStep) || (NewGainValue < FeatureMin) || (NewGainValue > FeatureMax))
									{
										printf( "\n\nEnter a valid Gain/Contrast value between %ld and %ld in steps of %ld\n",FeatureMin,FeatureMax,FeatureStep);
										scanf_s( "%ld", &NewGainValue );
									}

									getchar();

									fNewGainValue = (float)NewGainValue;
								}
								
								// set the new Gain/Contrast feature value
								FeatureValue.featurevalue = fNewGainValue;
								if (dcam_extended(hDCAM,DCAM_IDMSG_SETGETPARAM,&FeatureValue,sizeof(DCAM_PARAM_FEATURE)))
								{
									if (FeatureInquiry.units[0])
										printf("\n\nA Gain/Contrast value of %f %s was returned from the camera.",FeatureValue.featurevalue,FeatureInquiry.units);
									else
										printf("\n\nA Gain/Contrast value of %ld was returned from the camera.",(long)FeatureValue.featurevalue);
								}
								else
									printf("\n\nAn error occurred trying to set/get the Gain/Contrast value of the camera.");
							}
						}

						// *****************************
						// Query Offset feature
						// *****************************
						memset( &FeatureInquiry, 0, sizeof(DCAM_PARAM_FEATURE_INQ));
						FeatureInquiry.hdr.cbSize = sizeof(DCAM_PARAM_FEATURE_INQ);
						FeatureInquiry.hdr.id = DCAM_IDPARAM_FEATURE_INQ;
						
						memset( &FeatureValue, 0, sizeof(DCAM_PARAM_FEATURE));
						FeatureValue.hdr.cbSize = sizeof(DCAM_PARAM_FEATURE);
						FeatureValue.hdr.id = DCAM_IDPARAM_FEATURE;

						FeatureInquiry.featureid = FeatureValue.featureid = DCAM_IDFEATURE_OFFSET;
						if (dcam_extended(hDCAM,DCAM_IDMSG_GETPARAM,&FeatureInquiry,sizeof(DCAM_PARAM_FEATURE_INQ)))
						{
							float fNewOffsetValue = -65536.0;

							// get the current Offset feature value
							if (dcam_extended(hDCAM,DCAM_IDMSG_GETPARAM,&FeatureValue,sizeof(DCAM_PARAM_FEATURE)))
							{
								if (FeatureInquiry.units[0])
									printf("\n\n\nThe current Offset value is %f %s.",FeatureValue.featurevalue,FeatureInquiry.units);
								else
									printf("\n\n\nThe current Offset value is %ld.",(long)FeatureValue.featurevalue);
							}
							else
								printf("\n\n\nAn error occurred trying to get the Offset value of the camera.");

							// check if we can set this feature
							if (FeatureInquiry.step)
							{
								// check to see if this feature is relative or absolute with defined units
								if (FeatureInquiry.units[0])
								{
									// it is absolute with defined units
									while ((fNewOffsetValue < FeatureInquiry.min) || (fNewOffsetValue > FeatureInquiry.max))
									{
										printf( "\n\nEnter a valid Offset value between %f and %f %s\n",(double)FeatureInquiry.min,(double)FeatureInquiry.max,FeatureInquiry.units);
										scanf_s( "%f", &fNewOffsetValue );
									}

									// round down to the nearest valid feature value
									fNewOffsetValue /= FeatureInquiry.step;
									fNewOffsetValue *= FeatureInquiry.step;

									getchar();
								}
								else
								{
									// it is relative only
									long NewOffsetValue = -65536;
									long FeatureStep = (long)FeatureInquiry.step;
									long FeatureMin = (long)FeatureInquiry.min;
									long FeatureMax = (long)FeatureInquiry.max;
									while ((NewOffsetValue % FeatureStep) || (NewOffsetValue < FeatureMin) || (NewOffsetValue > FeatureMax))
									{
										printf( "\n\nEnter a valid Offset value between %ld and %ld in steps of %ld\n",FeatureMin,FeatureMax,FeatureStep);
										scanf_s( "%ld", &NewOffsetValue );
									}

									getchar();

									fNewOffsetValue = (float)NewOffsetValue;
								}
								
								FeatureValue.featurevalue = fNewOffsetValue;
								if (dcam_extended(hDCAM,DCAM_IDMSG_SETGETPARAM,&FeatureValue,sizeof(DCAM_PARAM_FEATURE)))
								{
									if (FeatureInquiry.units[0])
										printf("\n\nAn Offset value of %f %s was returned from the camera.",FeatureValue.featurevalue,FeatureInquiry.units);
									else
										printf("\n\nAn Offset value of %ld was returned from the camera.",(long)FeatureValue.featurevalue);
								}
								else
									printf("\n\nAn error occurred trying to set/get the Offset value of the camera.");
							}
						}

						// *****************************
						// Query Temperature feature
						// *****************************
						memset( &FeatureInquiry, 0, sizeof(DCAM_PARAM_FEATURE_INQ));
						FeatureInquiry.hdr.cbSize = sizeof(DCAM_PARAM_FEATURE_INQ);
						FeatureInquiry.hdr.id = DCAM_IDPARAM_FEATURE_INQ;
						
						memset( &FeatureValue, 0, sizeof(DCAM_PARAM_FEATURE));
						FeatureValue.hdr.cbSize = sizeof(DCAM_PARAM_FEATURE);
						FeatureValue.hdr.id = DCAM_IDPARAM_FEATURE;

						FeatureInquiry.featureid = FeatureValue.featureid = DCAM_IDFEATURE_TEMPERATURE;
						if (dcam_extended(hDCAM,DCAM_IDMSG_GETPARAM,&FeatureInquiry,sizeof(DCAM_PARAM_FEATURE_INQ)))
						{
							float fNewTemperatureValue = -65536.0;

							// get the current Temperature feature value
							if (dcam_extended(hDCAM,DCAM_IDMSG_GETPARAM,&FeatureValue,sizeof(DCAM_PARAM_FEATURE)))
							{
								if (FeatureInquiry.units[0])
									printf("\n\n\nThe current Temperature value is %6.1f%s.",FeatureValue.featurevalue,FeatureInquiry.units);
								else
									printf("\n\n\nThe current Temperature value is %ld.",(long)FeatureValue.featurevalue);
							}
							else
								printf("\n\n\nAn error occurred trying to get the Temperature value of the camera.");

							// check if we can set this feature
							if (FeatureInquiry.step)
							{
								// check to see if this feature is relative or absolute with defined units
								if (FeatureInquiry.units[0])
								{
									// it is absolute with defined units
									while ((fNewTemperatureValue < FeatureInquiry.min) || (fNewTemperatureValue > FeatureInquiry.max))
									{
										printf( "\n\nEnter a valid Temperature value between %6.1f%s and %6.1f%s\n",(double)FeatureInquiry.min,FeatureInquiry.units,(double)FeatureInquiry.max,FeatureInquiry.units);
										scanf_s( "%f", &fNewTemperatureValue );
									}

									// round down to the nearest valid feature value
									fNewTemperatureValue /= FeatureInquiry.step;
									fNewTemperatureValue *= FeatureInquiry.step;

									getchar();
								}
								else
								{
									// it is relative only
									long NewTemperatureValue = -65536;
									long FeatureStep = (long)FeatureInquiry.step;
									long FeatureMin = (long)FeatureInquiry.min;
									long FeatureMax = (long)FeatureInquiry.max;
									while ((NewTemperatureValue % FeatureStep) || (NewTemperatureValue < FeatureMin) || (NewTemperatureValue > FeatureMax))
									{
										printf( "\n\nEnter a valid Temperature value between %ld and %ld in steps of %ld\n",FeatureMin,FeatureMax,FeatureStep);
										scanf_s( "%ld", &NewTemperatureValue );
									}

									getchar();

									fNewTemperatureValue = (float)NewTemperatureValue;
								}
								
								// set the new Temperature feature value
								FeatureValue.featurevalue = fNewTemperatureValue;
								if (dcam_extended(hDCAM,DCAM_IDMSG_SETGETPARAM,&FeatureValue,sizeof(DCAM_PARAM_FEATURE)))
								{
									if (FeatureInquiry.units[0])
										printf("\n\nA Temperature value of %6.1f%s was returned from the camera.",FeatureValue.featurevalue,FeatureInquiry.units);
									else
										printf("\n\nA Temperature value of %ld was returned from the camera.",(long)FeatureValue.featurevalue);
								}
								else
									printf("\n\nAn error occurred trying to set/get the Temperature value of the camera.");
							}
						}

						// *****************************
						// Query Exposure Time feature
						// *****************************

						// Get the current Exposure Time
						dcam_getexposuretime(hDCAM,&lfCurrentExposureTime);
				
						// Set the default Exposure Time
						fNewExposureTimeValue = (float)lfCurrentExposureTime;

						printf("\n\n\nThe current Exposure Time value is set to %f seconds.",lfCurrentExposureTime);

						memset( &FeatureInquiry, 0, sizeof(DCAM_PARAM_FEATURE_INQ));
						FeatureInquiry.hdr.cbSize = sizeof(DCAM_PARAM_FEATURE_INQ);
						FeatureInquiry.hdr.id = DCAM_IDPARAM_FEATURE_INQ;
						
						memset( &FeatureValue, 0, sizeof(DCAM_PARAM_FEATURE));
						FeatureValue.hdr.cbSize = sizeof(DCAM_PARAM_FEATURE);
						FeatureValue.hdr.id = DCAM_IDPARAM_FEATURE;

						// query Exposure Time feature first
						FeatureInquiry.featureid = FeatureValue.featureid = DCAM_IDFEATURE_EXPOSURETIME;	// same as DCAM_IDFEATURE_SHUTTER
						if (dcam_extended(hDCAM,DCAM_IDMSG_GETPARAM,&FeatureInquiry,sizeof(DCAM_PARAM_FEATURE_INQ)))
						{
							fNewExposureTimeValue = -65536.0f;

							// check if we can set this feature
							if (FeatureInquiry.step)
							{
								// check to see if this feature is relative or absolute with defined units
								if (FeatureInquiry.units[0])
								{
									// it is absolute with defined units
									while ((fNewExposureTimeValue < FeatureInquiry.min) || (fNewExposureTimeValue > FeatureInquiry.max))
									{
										printf( "\n\nEnter a valid Exposure Time value between %f and %f %s\n",(double)FeatureInquiry.min,(double)FeatureInquiry.max,FeatureInquiry.units);
										scanf_s( "%f", &fNewExposureTimeValue );
									}

									// round down to the nearest valid feature value
									fNewExposureTimeValue /= FeatureInquiry.step;
									fNewExposureTimeValue *= FeatureInquiry.step;

									getchar();

									if (USE_DCAM_BASIC_EXPOSURETIME_SET)
									{
										if (dcam_setexposuretime(hDCAM,(double)fNewExposureTimeValue))
										{
											if (dcam_getexposuretime(hDCAM,&lfCurrentExposureTime))
											{
												printf("\n\nThe Exposure Time of %f seconds was returned from the camera.",lfCurrentExposureTime);
												fNewExposureTimeValue = (float)lfCurrentExposureTime;
											}
											else
												printf("\n\nAn error occurred trying to get the Exposure Time value from the camera.");
										}
										else
										{
											printf("\n\nAn error occurred trying to set the Exposure Time value to the camera.");
											fNewExposureTimeValue = (float)lfCurrentExposureTime;	// reset
										}
									}
									else
									{
										FeatureValue.featurevalue = fNewExposureTimeValue;
										if (dcam_extended(hDCAM,DCAM_IDMSG_SETGETPARAM,&FeatureValue,sizeof(DCAM_PARAM_FEATURE)))
										{
											printf("\n\nThe Exposure Time of %f %s was returned from the camera.",FeatureValue.featurevalue,FeatureInquiry.units);
											fNewExposureTimeValue = FeatureValue.featurevalue;
										}
										else
											printf("\n\nAn error occurred trying to set/get the Exposure Time value of the camera.");
									}
								}
								else
								{
									// it is relative only
									long NewShutterValue = -65536;
									long FeatureStep = (long)FeatureInquiry.step;
									long FeatureMin = (long)FeatureInquiry.min;
									long FeatureMax = (long)FeatureInquiry.max;
									while ((NewShutterValue % FeatureStep) || (NewShutterValue < FeatureMin) || (NewShutterValue > FeatureMax))
									{
										printf( "\n\nEnter a valid Shutter value between %ld and %ld in steps of %ld\n",FeatureMin,FeatureMax,FeatureStep);
										scanf_s( "%ld", &NewShutterValue );
									}

									getchar();

									FeatureValue.featurevalue = (float)NewShutterValue;
									if (dcam_extended(hDCAM,DCAM_IDMSG_SETGETPARAM,&FeatureValue,sizeof(DCAM_PARAM_FEATURE)))
										printf("\n\nA Shutter value of %ld was returned from the camera.",(long)FeatureValue.featurevalue);
									else
										printf("\n\nAn error occurred trying to set/get the Exposure Time value of the camera.");
								}
							}
						}

						// ******************
						// Start Acquisition
						// ******************
						if (dcam_getdatasizeex(hDCAM,&FinalImageSize))
						{
							DCAM_DATATYPE	DataType = DCAM_DATATYPE_NONE;

							if (dcam_getdatatype(hDCAM,&DataType))
							{
								long BytesPerPixel = 1;

								switch (DataType) {
								case DCAM_DATATYPE_UINT8:
								case DCAM_DATATYPE_INT8:
									BytesPerPixel = 1;
									break;
								case DCAM_DATATYPE_UINT16:
								case DCAM_DATATYPE_INT16:
									BytesPerPixel = 2;
									break;
								case DCAM_DATATYPE_RGB24:
								case DCAM_DATATYPE_BGR24:
									BytesPerPixel = 3;
									break;
								case DCAM_DATATYPE_RGB48:
								case DCAM_DATATYPE_BGR48:
									BytesPerPixel = 6;
								}

								printf("\n\nThe capture image size is %ld x %ld Pixels x %ld Bytes Per Pixel.\n\n",FinalImageSize.cx,FinalImageSize.cy,BytesPerPixel);

								if (dcam_precapture(hDCAM, DCAM_CAPTUREMODE_SNAP ))
								{

								#if USE_DCAM_API_MEMORY_MANAGEMENT
									
									if (dcam_freeframe(hDCAM))
									{
										if (dcam_allocframe(hDCAM,NUMBER_OF_FRAMES))
										{
								
								#else
									
									void* UserMemoryBuffer[NUMBER_OF_FRAMES];
									_DWORD DataFrameByteSize;

									if (dcam_getdataframebytes(hDCAM,&DataFrameByteSize))
									{
										for (i = 0;i < NUMBER_OF_FRAMES;i++)
											UserMemoryBuffer[i] = malloc(DataFrameByteSize);

										if (dcam_attachbuffer(hDCAM,UserMemoryBuffer,sizeof(UserMemoryBuffer)))
										{

								#endif
											long TimeOut = (long) ((fNewExposureTimeValue + FrameReadoutTimeInq.framereadouttime * 10.0f) * 1000.0f);
											
											void* pTop;
											long pRowBytes;

											_DWORD Event = DCAM_EVENT_FRAMEEND;
											
											long NewestFrameIndex = -1;
											long TotalFrames = 0;
											
											FILE *LastGoodRawImageFile = NULL;
											char OutputImageFileName[32];
#ifdef DCAM_TARGETOS_IS_WIN32
											LARGE_INTEGER PerformanceFrequency;
											LARGE_INTEGER LastFrameTimeStamp;
											LARGE_INTEGER NewFrameTimeStamp;

											// According to the Platform SDK, on a multiprocessor machine, it should not matter which processor is called.
											// However, you can get different results on different processors due to bugs in the BIOS or the HAL.
											// Therefore, we will force this thread to process using the first processor to insure QueryPerformanceCounter()
											// is the most accurate.
											HANDLE hCurrentThread = GetCurrentThread();
											SetThreadAffinityMask (hCurrentThread,1);

											PerformanceFrequency.QuadPart = 0;
											QueryPerformanceFrequency(&PerformanceFrequency);
#endif // DCAM_TARGETOS_IS_WIN32
											if (dcam_capture(hDCAM))
											{
#ifdef DCAM_TARGETOS_IS_WIN32
												QueryPerformanceCounter(&LastFrameTimeStamp);
#endif // DCAM_TARGETOS_IS_WIN32

												for (i = 0;i < NUMBER_OF_FRAMES;i++)
												{
													// Get the current transfer information status
													if (dcam_gettransferinfo(hDCAM,&NewestFrameIndex,&TotalFrames))
													{
														// If the newest frame index is less than our current frame index, wait until this frame is captured.
														if (NewestFrameIndex < i)
														{
															printf("\n\nWaiting %ldms for frame index %ld....\n\n",TimeOut,i);
															if (!dcam_wait(hDCAM,&Event,TimeOut,NULL))
															{
																long WaitLastError = dcam_getlasterror(hDCAM,NULL,0);
																while (WaitLastError == DCAMERR_LOSTFRAME)
																{
																	printf("\n\nLost Frame Detected! Waiting for next good frame....\n\n");
																	WaitLastError = DCAMERR_NONE;
																	Event = DCAM_EVENT_FRAMEEND;
																	if (!dcam_wait(hDCAM,&Event,TimeOut,NULL))
																		WaitLastError = dcam_getlasterror(hDCAM,NULL,0);
																}
																if (WaitLastError == DCAMERR_NONE)
																{
#ifdef DCAM_TARGETOS_IS_WIN32
																	QueryPerformanceCounter(&NewFrameTimeStamp);
																	printf("Frame index %ld arrived in %f milliseconds.\n\n",i,(double)(NewFrameTimeStamp.QuadPart - LastFrameTimeStamp.QuadPart) / (double)PerformanceFrequency.QuadPart * 1000.0);
																	LastFrameTimeStamp.QuadPart = NewFrameTimeStamp.QuadPart;
#else // ! DCAM_TARGETOS_IS_WIN32
																	printf("Frame index %ld arrived.\n\n", i);
#endif // DCAM_TARGETOS_IS_WIN32

																}
																else
																{
																	printf("Error = 0x%08lX\ndcam_wait failed.\n\n",(_DWORD)WaitLastError);
																	break;	// abort
																}
															}
															else
															{
#ifdef DCAM_TARGETOS_IS_WIN32
																QueryPerformanceCounter(&NewFrameTimeStamp);
																printf("Frame index %ld arrived in %f milliseconds.\n\n",i,(double)(NewFrameTimeStamp.QuadPart - LastFrameTimeStamp.QuadPart) / (double)PerformanceFrequency.QuadPart * 1000.0);
																LastFrameTimeStamp.QuadPart = NewFrameTimeStamp.QuadPart;
#else // ! DCAM_TARGETOS_IS_WIN32
																printf("Frame index %ld arrived.\n\n",i);
#endif // DCAM_TARGETOS_IS_WIN32
															}
														}

														pTop = NULL;

												#if USE_DCAM_API_MEMORY_MANAGEMENT

														pRowBytes = 0;
														
														if (dcam_lockdata(hDCAM,&pTop,&pRowBytes,i) && pTop)
														
												#else

														pTop = UserMemoryBuffer[i];

												#endif
														
														{
															sprintf_s(_secure_buf(OutputImageFileName),"LastGoodImage - %ld.raw",i);
										
															fopen( LastGoodRawImageFile, OutputImageFileName, "w+b" );
															if( LastGoodRawImageFile != NULL )
															{
																fwrite (pTop, BytesPerPixel, FinalImageSize.cx * FinalImageSize.cy, LastGoodRawImageFile);
																
																fclose (LastGoodRawImageFile);

																printf("Stored a frame into %s\n\n",OutputImageFileName);
															}

													#if USE_DCAM_API_MEMORY_MANAGEMENT
												
															dcam_unlockdata(hDCAM);
														}
														else
															printf("Error = 0x%08lX\ndcam_lockdata on frame index %ld failed.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0),i);

													#else

														}

													#endif


													}
													else
													{
														printf("Error = 0x%08lX\ndcam_gettransferinfo failed.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));
														break;	// abort
													}
												}

												printf("Capturing complete.\n\n");

												if (dcam_idle(hDCAM))
												{
												
												#if USE_DCAM_API_MEMORY_MANAGEMENT
													
													dcam_freeframe(hDCAM);

												#else

													dcam_releasebuffer(hDCAM);

													for (i = 0;i < NUMBER_OF_FRAMES;i++)
														free(UserMemoryBuffer[i]);

												#endif

													printf("Process completed successfully.\n\n");
												}
												else
													printf("Error = 0x%08lX\ndcam_idle failed.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));
											}
											else
												printf("Error = 0x%08lX\ndcam_capture failed.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));

								#if USE_DCAM_API_MEMORY_MANAGEMENT

										}
										else
											printf("Error = 0x%08lX\ndcam_allocframe failed.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));
									}
									else
										printf("Error = 0x%08lX\ndcam_freeframe failed.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));

								#else

										}
										else
											printf("Error = 0x%08lX\ndcam_attachbuffer failed.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));
									}
									else
										printf("Error = 0x%08lX\ndcam_getdataframebytes failed.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));

								#endif

								}
								else
									printf("Error = 0x%08lX\ndcam_precapture failed.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));
							}
							else
								printf("Error = 0x%08lX\nCould not get the data type of the camera.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));
						}
						else
							printf("Error = 0x%08lX\nCould not get the data size of the camera.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));

						// *********************
						// Re-Initialize Camera
						// *********************
						memset( &FeatureValue, 0, sizeof(DCAM_PARAM_FEATURE));
						FeatureValue.hdr.cbSize = sizeof(DCAM_PARAM_FEATURE);
						FeatureValue.hdr.id = DCAM_IDPARAM_FEATURE;

						FeatureInquiry.featureid = FeatureValue.featureid = DCAM_IDFEATURE_INITIALIZE;
						if (dcam_extended(hDCAM,DCAM_IDMSG_SETPARAM,&FeatureValue,sizeof(DCAM_PARAM_FEATURE)))
							printf("\n\nCamera re-initialized successfully.\n\n");
						else
						{
							long LastError = dcam_getlasterror(hDCAM,NULL,0);
							if (LastError == DCAMERR_NOTSUPPORT)
								printf("\n\nCamera re-initialized not supported.");
							else
								printf("\n\nAn error 0x%08lX occurred trying to re-initialize the camera.",(_DWORD)LastError);
						}
					}
				}
				else
					printf("Error = 0x%08lX\nCould not get the capability of the camera.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));
			}
			else
				printf("Error = 0x%08lX\nCould not get the Model name string of the camera.\n\n",(_DWORD)dcam_getlasterror(hDCAM,NULL,0));

			dcam_close (hDCAM);
		}
		else
			printf("Could not open camera index 0 of DCAM-API.\n\n");

		dcam_uninit(NULL,NULL);
	}
	else
		printf("Could not initialize DCAM-API. There may be no cameras detected!\n\n");
	
	return 0;
}
