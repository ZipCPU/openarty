#!bin/bash

./wbregs flashcfg 0x0001000	# Activate config mode
./wbregs flashcfg 0x00010ff	# Send 16(*4) bits of ones, break the mode
./wbregs flashcfg 0x00010ff
./wbregs flashcfg 0x00010ff
./wbregs flashcfg 0x00010ff
./wbregs flashcfg 0x0001100	# Inactivate the port

# Reset the SCOPE
./wbregs qscope 0x07ffff
# echo READ-ID
./wbregs flashcfg 0x000109f	# Issue the read ID command
./wbregs flashcfg 0x0001000	# Read the ID
./wbregs flashcfg
./wbregs flashcfg 0x0001000	#
./wbregs flashcfg
./wbregs flashcfg 0x0001000	#
./wbregs flashcfg
./wbregs flashcfg 0x0001000	#
./wbregs flashcfg
./wbregs flashcfg 0x0001100	# End the command

echo Return to QSPI
# ./wbregs flashcfg 0x00010eb	# Return us to QSPI mode, via QIO_READ cmd
# ./wbregs flashcfg 0x0001a00	# dummy address
# ./wbregs flashcfg 0x0001a00	# dummy address
# ./wbregs flashcfg 0x0001a00	# dummy address
# ./wbregs flashcfg 0x0001aa0	# mode byte
# ./wbregs flashcfg 0x0001800	# empty byte, switching directions
# ./wbregs flashcfg 0x0001900	# Raise (deactivate) CS_n
# ./wbregs flashcfg 0x0000100	# Return to user mode
