set -e

PASM=prettyasm/main.js
BIN2WAV=../bin2wav/bin2wav.js
ZX0=./tools/zx0.exe
PNG2DB=./tools/png2db-arzak.py

ZX0_ORG=4000

RSOUND="-DRSOUND=0"

SONGE="unit5vi53"


MAIN=wave
ROM=$MAIN-raw.rom
ROMZ=$MAIN.rom
WAV=$MAIN.wav
ROM_ZX0=$MAIN.zx0
DZX0_BIN=dzx0-fwd.$ZX0_ORG
RELOC=reloc-zx0
RELOC_BIN=$RELOC.0100

rm -f $ROM_ZX0 $ROM

if ! test -e songe.inc ; then
  ./tools/ym6break.py music/$SONGE.ym songA_
  mv $SONGE.inc songe.inc
fi

if ! test -e fish.inc ; then
    $PNG2DB cheep1.png -mode bits8 -lineskip 1 -leftofs 0 -nplanes 2 \
        -lut 0,2,3,1 \
        -labels fisha0,fisha1 > fish.inc

    $PNG2DB cheep2.png -mode bits8 -lineskip 1 -leftofs 0 -nplanes 2 \
        -lut 0,2,3,1 \
        -labels fishb0,fishb1 >> fish.inc
fi

$PASM $RSOUND $MAIN.asm -o $ROM
$PASM $MAIN.asm -o $ROM
ROM_SZ=`cat $ROM | wc -c`
echo "$ROM: $ROM_SZ octets"

$ZX0 -c $ROM $ROM_ZX0
ROM_ZX0_SZ=`cat $ROM_ZX0 | wc -c`
echo "$ROM_ZX0: $ROM_ZX0_SZ octets"

$PASM -Ddzx0_org=0x$ZX0_ORG dzx0-fwd.asm -o $DZX0_BIN
DZX0_SZ=`cat $DZX0_BIN | wc -c`
echo "$DZX0_BIN: $DZX0_SZ octets"

$PASM -Ddst=0x$ZX0_ORG -Ddzx_sz=$DZX0_SZ -Ddata_sz=$ROM_ZX0_SZ $RELOC.asm -o $RELOC_BIN
RELOC_SZ=`cat $RELOC_BIN | wc -c`
echo "$RELOC_BIN: $RELOC_SZ octets"

cat $RELOC_BIN $DZX0_BIN $ROM_ZX0 > $ROMZ

#$BIN2WAV -m v06c-turbo $ROMZ $WAV
$BIN2WAV -c 5 -m v06c-turbo $ROMZ $WAV
