## This file is a general .xdc for the ARTY Rev. B
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

# Config setup
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## Clock signal

set_property PACKAGE_PIN E3 [get_ports {sys_clk_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {sys_clk_i}]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports {sys_clk_i}]

##Switches

set_property -dict { PACKAGE_PIN A8  IOSTANDARD LVCMOS33 } [get_ports {i_sw[0]}]
set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports {i_sw[1]}]
set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports {i_sw[2]}]
set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports {i_sw[3]}]

##RGB LEDs

set_property -dict { PACKAGE_PIN E1 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led0[0]}]
set_property -dict { PACKAGE_PIN F6 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led0[1]}]
set_property -dict { PACKAGE_PIN G6 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led0[2]}]
set_property -dict { PACKAGE_PIN G4 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led1[0]}]
set_property -dict { PACKAGE_PIN J4 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led1[1]}]
set_property -dict { PACKAGE_PIN G3 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led1[2]}]
set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led2[0]}]
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led2[1]}]
set_property -dict { PACKAGE_PIN J3 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led2[2]}]
set_property -dict { PACKAGE_PIN K2 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led3[0]}]
set_property -dict { PACKAGE_PIN H6 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led3[1]}]
set_property -dict { PACKAGE_PIN K1 IOSTANDARD LVCMOS33 } [get_ports {o_clr_led3[2]}]

##LEDs

set_property -dict { PACKAGE_PIN  H5 IOSTANDARD LVCMOS33 } [get_ports {o_led[0]}]
set_property -dict { PACKAGE_PIN  J5 IOSTANDARD LVCMOS33 } [get_ports {o_led[1]}]
set_property -dict { PACKAGE_PIN  T9 IOSTANDARD LVCMOS33 } [get_ports {o_led[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {o_led[3]}]

##Buttons

set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports {i_btn[0]}]
set_property -dict { PACKAGE_PIN C9 IOSTANDARD LVCMOS33 } [get_ports {i_btn[1]}]
set_property -dict { PACKAGE_PIN B9 IOSTANDARD LVCMOS33 } [get_ports {i_btn[2]}]
set_property -dict { PACKAGE_PIN B8 IOSTANDARD LVCMOS33 } [get_ports {i_btn[3]}]

##Pmod Header JA: PModCLS (bottom)

#set_property -dict { PACKAGE_PIN G13   IOSTANDARD LVCMOS33 } [get_ports { ja[0] }]; #IO_0_15 Sch=ja[1]
#set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { ja[1] }]; #IO_L4P_T0_15 Sch=ja[2]
#set_property -dict { PACKAGE_PIN A11   IOSTANDARD LVCMOS33 } [get_ports { ja[2] }]; #IO_L4N_T0_15 Sch=ja[3]
#set_property -dict { PACKAGE_PIN D12   IOSTANDARD LVCMOS33 } [get_ports { ja[3] }]; #IO_L6P_T0_15 Sch=ja[4]
#-- set_property -dict { PACKAGE_PIN D13   IOSTANDARD LVCMOS33 } [get_ports { o_cls_ss_n }]; #IO_L6N_T0_VREF_15 Sch=ja[7]
#-- set_property -dict { PACKAGE_PIN B18   IOSTANDARD LVCMOS33 } [get_ports { o_cls_mosi }]; #IO_L10P_T1_AD11P_15 Sch=ja[8]
#-- set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS33 } [get_ports { i_cls_miso }]; #IO_L10N_T1_AD11N_15 Sch=ja[9]
#-- set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { o_cls_sck }]; #IO_25_15 Sch=ja[10]

##Pmod Header JB: OLEDrgb

set_property -dict { PACKAGE_PIN E15 IOSTANDARD LVCMOS33 } [get_ports o_oled_cs_n]
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports o_oled_mosi]
#set_property -dict { PACKAGE_PIN D15   IOSTANDARD LVCMOS33 } [get_ports { i_oled_nc }]; #IO_L12P_T1_MRCC_15 Sch=jb_p[2]
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports o_oled_sck]
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports o_oled_dcn]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports o_oled_reset_n]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports o_oled_vccen]
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports o_oled_pmoden]

##Pmod Header JC: GPS (top), UART (bottom)

set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports i_gps_3df]
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports o_gps_tx]
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports i_gps_rx]
set_property -dict { PACKAGE_PIN V11 IOSTANDARD LVCMOS33 } [get_ports i_gps_pps]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports i_aux_rts]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports o_aux_tx]
set_property -dict { PACKAGE_PIN T13 IOSTANDARD LVCMOS33 } [get_ports i_aux_rx]
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports o_aux_cts]

##Pmod Header JD: SD-Card

set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 } [get_ports {io_sd[3]}]
set_property -dict { PACKAGE_PIN D3 IOSTANDARD LVCMOS33 } [get_ports io_sd_cmd]
set_property -dict { PACKAGE_PIN F4 IOSTANDARD LVCMOS33 } [get_ports {io_sd[0]}]
set_property -dict { PACKAGE_PIN F3 IOSTANDARD LVCMOS33 } [get_ports o_sd_sck]
set_property -dict { PACKAGE_PIN E2 IOSTANDARD LVCMOS33 } [get_ports {io_sd[1]}]
set_property -dict { PACKAGE_PIN D2 IOSTANDARD LVCMOS33 } [get_ports {io_sd[2]}]
set_property -dict { PACKAGE_PIN H2 IOSTANDARD LVCMOS33 } [get_ports i_sd_cs]
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 } [get_ports i_sd_wp]

##USB-UART Interface
# THESE ARE CORRECT
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports o_uart_tx]
set_property -dict { PACKAGE_PIN A9  IOSTANDARD LVCMOS33 } [get_ports i_uart_rx]
#

##ChipKit Single Ended Analog Inputs
##NOTE: The ck_an_p pins can be used as single ended analog inputs with voltages from 0-3.3V (Chipkit Analog pins A0-A5).
##      These signals should only be connected to the XADC core. When using these pins as digital I/O, use pins ck_io[14-19].

#set_property -dict { PACKAGE_PIN C5    IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[0] }]; #IO_L1N_T0_AD4N_35 Sch=ck_an_n[0]
#set_property -dict { PACKAGE_PIN C6    IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[0] }]; #IO_L1P_T0_AD4P_35 Sch=ck_an_p[0]
#set_property -dict { PACKAGE_PIN A5    IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[1] }]; #IO_L3N_T0_DQS_AD5N_35 Sch=ck_an_n[1]
#set_property -dict { PACKAGE_PIN A6    IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[1] }]; #IO_L3P_T0_DQS_AD5P_35 Sch=ck_an_p[1]
#set_property -dict { PACKAGE_PIN B4    IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[2] }]; #IO_L7N_T1_AD6N_35 Sch=ck_an_n[2]
#set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[2] }]; #IO_L7P_T1_AD6P_35 Sch=ck_an_p[2]
#set_property -dict { PACKAGE_PIN A1    IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[3] }]; #IO_L9N_T1_DQS_AD7N_35 Sch=ck_an_n[3]
#set_property -dict { PACKAGE_PIN B1    IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[3] }]; #IO_L9P_T1_DQS_AD7P_35 Sch=ck_an_p[3]
#set_property -dict { PACKAGE_PIN B2    IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[4] }]; #IO_L10N_T1_AD15N_35 Sch=ck_an_n[4]
#set_property -dict { PACKAGE_PIN B3    IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[4] }]; #IO_L10P_T1_AD15P_35 Sch=ck_an_p[4]
#set_property -dict { PACKAGE_PIN C14   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[5] }]; #IO_L1N_T0_AD0N_15 Sch=ck_an_n[5]
#set_property -dict { PACKAGE_PIN D14   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[5] }]; #IO_L1P_T0_AD0P_15 Sch=ck_an_p[5]

##ChipKit Digital I/O Low

#set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[0] }]; #IO_L16P_T2_CSI_B_14 Sch=ck_io[0]
#set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[1] }]; #IO_L18P_T2_A12_D28_14 Sch=ck_io[1]
#set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { ck_io[2] }]; #IO_L8N_T1_D12_14 Sch=ck_io[2]
#set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { ck_io[3] }]; #IO_L19P_T3_A10_D26_14 Sch=ck_io[3]
#set_property -dict { PACKAGE_PIN R12   IOSTANDARD LVCMOS33 } [get_ports { ck_io[4] }]; #IO_L5P_T0_D06_14 Sch=ck_io[4]
#set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { ck_io[5] }]; #IO_L14P_T2_SRCC_14 Sch=ck_io[5]
#set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[6] }]; #IO_L14N_T2_SRCC_14 Sch=ck_io[6]
#set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[7] }]; #IO_L15N_T2_DQS_DOUT_CSO_B_14 Sch=ck_io[7]
#set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[8] }]; #IO_L11P_T1_SRCC_14 Sch=ck_io[8]
#set_property -dict { PACKAGE_PIN M16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[9] }]; #IO_L10P_T1_D14_14 Sch=ck_io[9]
#set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[10] }]; #IO_L18N_T2_A11_D27_14 Sch=ck_io[10]
#set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[11] }]; #IO_L17N_T2_A13_D29_14 Sch=ck_io[11]
#set_property -dict { PACKAGE_PIN R17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[12] }]; #IO_L12N_T1_MRCC_14 Sch=ck_io[12]
#set_property -dict { PACKAGE_PIN P17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[13] }]; #IO_L12P_T1_MRCC_14 Sch=ck_io[13]

##ChipKit Digital I/O On Outer Analog Header
##NOTE: These pins should be used when using the analog header signals A0-A5 as digital I/O (Chipkit digital pins 14-19)

#set_property -dict { PACKAGE_PIN F5    IOSTANDARD LVCMOS33 } [get_ports { ck_io[14] }]; #IO_0_35 Sch=ck_a[0]
#set_property -dict { PACKAGE_PIN D8    IOSTANDARD LVCMOS33 } [get_ports { ck_io[15] }]; #IO_L4P_T0_35 Sch=ck_a[1]
#set_property -dict { PACKAGE_PIN C7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[16] }]; #IO_L4N_T0_35 Sch=ck_a[2]
#set_property -dict { PACKAGE_PIN E7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[17] }]; #IO_L6P_T0_35 Sch=ck_a[3]
#set_property -dict { PACKAGE_PIN D7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[18] }]; #IO_L6N_T0_VREF_35 Sch=ck_a[4]
#set_property -dict { PACKAGE_PIN D5    IOSTANDARD LVCMOS33 } [get_ports { ck_io[19] }]; #IO_L11P_T1_SRCC_35 Sch=ck_a[5]

##ChipKit Digital I/O On Inner Analog Header
##NOTE: These pins will need to be connected to the XADC core when used as differential analog inputs (Chipkit analog pins A6-A11)

#set_property -dict { PACKAGE_PIN B7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[20] }]; #IO_L2P_T0_AD12P_35 Sch=ad_p[12]
#set_property -dict { PACKAGE_PIN B6    IOSTANDARD LVCMOS33 } [get_ports { ck_io[21] }]; #IO_L2N_T0_AD12N_35 Sch=ad_n[12]
#set_property -dict { PACKAGE_PIN E6    IOSTANDARD LVCMOS33 } [get_ports { ck_io[22] }]; #IO_L5P_T0_AD13P_35 Sch=ad_p[13]
#set_property -dict { PACKAGE_PIN E5    IOSTANDARD LVCMOS33 } [get_ports { ck_io[23] }]; #IO_L5N_T0_AD13N_35 Sch=ad_n[13]
#set_property -dict { PACKAGE_PIN A4    IOSTANDARD LVCMOS33 } [get_ports { ck_io[24] }]; #IO_L8P_T1_AD14P_35 Sch=ad_p[14]
#set_property -dict { PACKAGE_PIN A3    IOSTANDARD LVCMOS33 } [get_ports { ck_io[25] }]; #IO_L8N_T1_AD14N_35 Sch=ad_n[14]

##ChipKit Digital I/O High

#set_property -dict { PACKAGE_PIN U11   IOSTANDARD LVCMOS33 } [get_ports { ck_io[26] }]; #IO_L19N_T3_A09_D25_VREF_14 Sch=ck_io[26]
#set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[27] }]; #IO_L16N_T2_A15_D31_14 Sch=ck_io[27]
#set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS33 } [get_ports { ck_io[28] }]; #IO_L6N_T0_D08_VREF_14 Sch=ck_io[28]
#set_property -dict { PACKAGE_PIN R10   IOSTANDARD LVCMOS33 } [get_ports { ck_io[29] }]; #IO_25_14 Sch=ck_io[29]
#set_property -dict { PACKAGE_PIN R11   IOSTANDARD LVCMOS33 } [get_ports { ck_io[30] }]; #IO_0_14 Sch=ck_io[30]
#set_property -dict { PACKAGE_PIN R13   IOSTANDARD LVCMOS33 } [get_ports { ck_io[31] }]; #IO_L5N_T0_D07_14 Sch=ck_io[31]
#set_property -dict { PACKAGE_PIN R15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[32] }]; #IO_L13N_T2_MRCC_14 Sch=ck_io[32]
#set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[33] }]; #IO_L13P_T2_MRCC_14 Sch=ck_io[33]
#set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[34] }]; #IO_L15P_T2_DQS_RDWR_B_14 Sch=ck_io[34]
#set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[35] }]; #IO_L11N_T1_SRCC_14 Sch=ck_io[35]
#set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { ck_io[36] }]; #IO_L8P_T1_D11_14 Sch=ck_io[36]
#set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[37] }]; #IO_L17P_T2_A14_D30_14 Sch=ck_io[37]
#set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[38] }]; #IO_L7N_T1_D10_14 Sch=ck_io[38]
#set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[39] }]; #IO_L7P_T1_D09_14 Sch=ck_io[39]
#set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[40] }]; #IO_L9N_T1_DQS_D13_14 Sch=ck_io[40]
#set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[41] }]; #IO_L9P_T1_DQS_14 Sch=ck_io[41]

## ChipKit SPI

#set_property -dict { PACKAGE_PIN G1    IOSTANDARD LVCMOS33 } [get_ports { ck_miso }]; #IO_L17N_T2_35 Sch=ck_miso
#set_property -dict { PACKAGE_PIN H1    IOSTANDARD LVCMOS33 } [get_ports { ck_mosi }]; #IO_L17P_T2_35 Sch=ck_mosi
#set_property -dict { PACKAGE_PIN F1    IOSTANDARD LVCMOS33 } [get_ports { ck_sck }]; #IO_L18P_T2_35 Sch=ck_sck
#set_property -dict { PACKAGE_PIN C1    IOSTANDARD LVCMOS33 } [get_ports { ck_ss }]; #IO_L16N_T2_35 Sch=ck_ss

## ChipKit I2C

#set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports { ck_scl }]; #IO_L4P_T0_D04_14 Sch=ck_scl
#set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { ck_sda }]; #IO_L4N_T0_D05_14 Sch=ck_sda
#set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports { scl_pup }]; #IO_L9N_T1_DQS_AD3N_15 Sch=scl_pup
#set_property -dict { PACKAGE_PIN A13   IOSTANDARD LVCMOS33 } [get_ports { sda_pup }]; #IO_L9P_T1_DQS_AD3P_15 Sch=sda_pup

##Misc. ChipKit signals

#set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { ck_ioa }]; #IO_L10N_T1_D15_14 Sch=ck_ioa
set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports i_reset_btn]

##SMSC Ethernet PHY

set_property -dict { PACKAGE_PIN D17   IOSTANDARD LVCMOS33 } [get_ports { i_eth_col }]; #IO_L16N_T2_A27_15 Sch=eth_col
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { i_eth_crs }]; #IO_L15N_T2_DQS_ADV_B_15 Sch=eth_crs
set_property -dict { PACKAGE_PIN F16 IOSTANDARD LVCMOS33 } [get_ports o_eth_mdclk]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports io_eth_mdio]
set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { o_eth_ref_clk }]; #IO_L22P_T3_A17_15 Sch=eth_ref_clk
set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { o_eth_rstn }]; #IO_L20P_T3_A20_15 Sch=eth_rstn
set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { i_eth_rx_clk }]; #IO_L14P_T2_SRCC_15 Sch=eth_rx_clk
set_property -dict { PACKAGE_PIN G16   IOSTANDARD LVCMOS33 } [get_ports { i_eth_rx_dv }]; #IO_L13N_T2_MRCC_15 Sch=eth_rx_dv
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { i_eth_rxd[0] }]; #IO_L21N_T3_DQS_A18_15 Sch=eth_rxd[0]
set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { i_eth_rxd[1] }]; #IO_L16P_T2_A28_15 Sch=eth_rxd[1]
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { i_eth_rxd[2] }]; #IO_L21P_T3_DQS_15 Sch=eth_rxd[2]
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { i_eth_rxd[3] }]; #IO_L18N_T2_A23_15 Sch=eth_rxd[3]
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { i_eth_rxerr }]; #IO_L20N_T3_A19_15 Sch=eth_rxerr
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { i_eth_tx_clk }]; #IO_L13P_T2_MRCC_15 Sch=eth_tx_clk
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { o_eth_tx_en }]; #IO_L19N_T3_A21_VREF_15 Sch=eth_tx_en
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { o_eth_txd[0] }]; #IO_L15P_T2_DQS_15 Sch=eth_txd[0]
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { o_eth_txd[1] }]; #IO_L19P_T3_A22_15 Sch=eth_txd[1]
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { o_eth_txd[2] }]; #IO_L17N_T2_A25_15 Sch=eth_txd[2]
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { o_eth_txd[3] }]; #IO_L18P_T2_A24_15 Sch=eth_txd[3]

# Ethernet generated clocks from the chip
create_clock -period 40.000 -name eth_tx_pin -add [get_ports {i_eth_tx_clk}]
create_clock -period 40.000 -name eth_rx_pin -add [get_ports {i_eth_rx_clk}]

# And crossing clocks from ethernet clocks to master clock
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME=~ *netctrl/r_*}] -to [get_cells -hier -filter {NAME =~ *netctrl/n_*}] 12.3;
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME=~ *netctrl/n_*}] -to [get_cells -hier -filter {NAME =~ *netctrl/r_*}] 12.3;
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME=~ *netctrl/tx_len*}] -to [get_cells -hier -filter {NAME =~ *netctrl/n_*}] 12.3;
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME=~ *netctrl/n_rx_len*}] -to [get_cells -hier -filter {NAME =~ *netctrl/rx_le*}] 12.3;
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME=~ *netctrl/config_*}] -to [get_cells -hier -filter {NAME =~ *netctrl/n_*}] 12.3;
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME=~ *netctrl/preambl*}] -to [get_cells -hier -filter {NAME =~ *netctrl/n_next_pr*}] 12.3;
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME=~ *netctrl/rx_cl*}] -to [get_cells -hier -filter {NAME =~ *netctrl/r_rx_clea*}] 12.3;
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME=~ *netctrl/tx_cm*}] -to [get_cells -hier -filter {NAME =~ *netctrl/r_tx_cm*}] 12.3;
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME=~ *netctrl/tx_can*}] -to [get_cells -hier -filter {NAME =~ *netctrl/r_tx_can*}] 12.3;
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME=~ *netctrl/n_rx_miss*}] -to [get_cells -hier -filter {NAME =~ *netctrl/rx_miss_st*}] 12.3;
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME=~ *netctrl/n_rx_err*}] -to [get_cells -hier -filter {NAME =~ *netctrl/rx_err_st*}] 12.3;

##Quad SPI Flash

set_property -dict { PACKAGE_PIN L13 IOSTANDARD LVCMOS33 } [get_ports o_qspi_cs_n]
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports {io_qspi_dat[0]}]
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports {io_qspi_dat[1]}]
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports {io_qspi_dat[2]}]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports {io_qspi_dat[3]}]
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports o_qspi_sck]

##Power Measurements

#set_property -dict { PACKAGE_PIN B17   IOSTANDARD LVCMOS33     } [get_ports { vsnsvu_n }]; #IO_L7N_T1_AD2N_15 Sch=ad_n[2]
#set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS33     } [get_ports { vsnsvu_p }]; #IO_L7P_T1_AD2P_15 Sch=ad_p[2]
#set_property -dict { PACKAGE_PIN B12   IOSTANDARD LVCMOS33     } [get_ports { vsns5v0_n }]; #IO_L3N_T0_DQS_AD1N_15 Sch=ad_n[1]
#set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33     } [get_ports { vsns5v0_p }]; #IO_L3P_T0_DQS_AD1P_15 Sch=ad_p[1]
#set_property -dict { PACKAGE_PIN F14   IOSTANDARD LVCMOS33     } [get_ports { isns5v0_n }]; #IO_L5N_T0_AD9N_15 Sch=ad_n[9]
#set_property -dict { PACKAGE_PIN F13   IOSTANDARD LVCMOS33     } [get_ports { isns5v0_p }]; #IO_L5P_T0_AD9P_15 Sch=ad_p[9]
#set_property -dict { PACKAGE_PIN A16   IOSTANDARD LVCMOS33     } [get_ports { isns0v95_n }]; #IO_L8N_T1_AD10N_15 Sch=ad_n[10]
#set_property -dict { PACKAGE_PIN A15   IOSTANDARD LVCMOS33     } [get_ports { isns0v95_p }]; #IO_L8P_T1_AD10P_15 Sch=ad_p[10]

## Memory
#
# While valid definitions below, these definitions conflict with the XDC file
# created by the Memory Interface Generator (MIG), and so these have been
# commented out.
#
## Memory address lines
#set_property -dict { PACKAGE_PIN R2 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[0]}]
#set_property -dict { PACKAGE_PIN M6 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[1]}]
#set_property -dict { PACKAGE_PIN N4 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[2]}]
#set_property -dict { PACKAGE_PIN T1 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[3]}]
#set_property -dict { PACKAGE_PIN N6 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[4]}]
#set_property -dict { PACKAGE_PIN R7 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[5]}]
#set_property -dict { PACKAGE_PIN V6 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[6]}]
#set_property -dict { PACKAGE_PIN U7 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[7]}]
#set_property -dict { PACKAGE_PIN R8 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[8]}]
#set_property -dict { PACKAGE_PIN V7 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[9]}]
#set_property -dict { PACKAGE_PIN R6 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[10]}]
#set_property -dict { PACKAGE_PIN U6 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[11]}]
#set_property -dict { PACKAGE_PIN T6 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[12]}]
#set_property -dict { PACKAGE_PIN T8 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_addr[13]}]
#set_property -dict { PACKAGE_PIN R1 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_ba[0]}]
#set_property -dict { PACKAGE_PIN P4 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_ba[1]}]
#set_property -dict { PACKAGE_PIN P2 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_ba[2]}]
#
## Clock lines
#
#set_property -dict { PACKAGE_PIN U9 IOSTANDARD DIFF_SSTL135 SLEW FAST } [get_ports {ddr3_ck_p[0]}]
#set_property -dict { PACKAGE_PIN V9 IOSTANDARD DIFF_SSTL135 SLEW FAST } [get_ports {ddr3_ck_n[0]}]
#
##
#set_property -dict { PACKAGE_PIN L1 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_dm[0]}]
#set_property -dict { PACKAGE_PIN U1 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_dm[1]}]
## Data (DQ) lines
#set_property -dict { PACKAGE_PIN K5 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[0]}]
#set_property -dict { PACKAGE_PIN L3 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[1]}]
#set_property -dict { PACKAGE_PIN K3 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[2]}]
#set_property -dict { PACKAGE_PIN L6 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[3]}]
#set_property -dict { PACKAGE_PIN M3 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[4]}]
#set_property -dict { PACKAGE_PIN M1 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[5]}]
#set_property -dict { PACKAGE_PIN L4 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[6]}]
#set_property -dict { PACKAGE_PIN M2 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[7]}]
#set_property -dict { PACKAGE_PIN V4 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[8]}]
#set_property -dict { PACKAGE_PIN T5 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[9]}]
#set_property -dict { PACKAGE_PIN U4 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[10]}]
#set_property -dict { PACKAGE_PIN V5 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[11]}]
#set_property -dict { PACKAGE_PIN V1 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[12]}]
#set_property -dict { PACKAGE_PIN T3 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[13]}]
#set_property -dict { PACKAGE_PIN U3 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[14]}]
#set_property -dict { PACKAGE_PIN R3 IOSTANDARD SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dq[15]}]
# DQS
#set_property -dict { PACKAGE_PIN N2 IOSTANDARD DIFF_SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dqs_p[0]}]
#set_property -dict { PACKAGE_PIN U2 IOSTANDARD DIFF_SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dqs_p[1]}]
#set_property -dict { PACKAGE_PIN N1 IOSTANDARD DIFF_SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dqs_n[0]}]
#set_property -dict { PACKAGE_PIN V2 IOSTANDARD DIFF_SSTL135 SLEW FAST IN_TERM UNTUNED_SPLIT_50 } [get_ports {ddr3_dqs_n[1]}]
## Command wires
#set_property -dict { PACKAGE_PIN K6 IOSTANDARD SSTL135 SLEW FAST } [get_ports ddr3_reset_n]
#set_property -dict { PACKAGE_PIN N5 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_cke[0]}]
#set_property -dict { PACKAGE_PIN U8 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_cs_n[0]}]
#set_property -dict { PACKAGE_PIN P3 IOSTANDARD SSTL135 SLEW FAST } [get_ports ddr3_ras_n]
#set_property -dict { PACKAGE_PIN M4 IOSTANDARD SSTL135 SLEW FAST } [get_ports ddr3_cas_n]
#set_property -dict { PACKAGE_PIN P5 IOSTANDARD SSTL135 SLEW FAST } [get_ports ddr3_we_n]
#set_property -dict { PACKAGE_PIN R5 IOSTANDARD SSTL135 SLEW FAST } [get_ports {ddr3_odt[0]}]
##Internal VREF
set_property INTERNAL_VREF 0.675 [get_iobanks 34]


set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.CCLKPIN PULLNONE [current_design]
set_property CONFIG_MODE SPIx1 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR NO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]


