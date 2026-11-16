#!/bin/bash
# balance_report.sh TAG: for each map and difficulty played under TAG, where each seed's battle ended
# (won, lost in which wave, or still going when the time ran out), the men bought and the men killed
# by their own side.
cd "${BAL_DIR:-/tmp/bal}" || exit 1
for md in $(ls ${1}_*.log 2>/dev/null | sed -E "s/^${1}_(.*)_[0-9]+\.log$/\1/" | sort -u); do
  out=""
  for f in ${1}_${md}_*.log; do
    seed=$(echo $f | sed -E 's/.*_([0-9]+)\.log/\1/')
    r=$(grep "RESULT" $f | head -1)
    if [ -z "$r" ]; then w=$(grep -c "beaten at" $f); res="running, $w waves beaten"; else
      if echo "$r" | grep -q "WON"; then res="WON"; elif echo "$r" | grep -q "OVERRUN"; then res="lost w$(echo "$r" | sed -E 's/.*OVERRUN in wave ([0-9]+).*/\1/')"; elif echo "$r" | grep -q "stopped after"; then res="stopped after w$(echo "$r" | sed -E 's/.*stopped after wave ([0-9]+).*/\1/')"; else res="time up in w$(echo "$r" | sed -E 's/.*in wave ([0-9]+).*/\1/')"; fi
      men=$(echo "$r" | grep -o '"man": [0-9]*' | grep -o '[0-9]*$'); m5=$(echo "$r" | grep -o '"men5": [0-9]*' | grep -o '[0-9]*$'); men=$(( ${men:-0} + 5 * ${m5:-0} ))
      tk=$(echo "$r" | sed -E 's/.*friendly-fire kills ([0-9]+).*/\1/'); res="$res, $men men bought, ff $tk"
      lost=$(grep "men lost to:" $f | head -1 | sed -E 's/.*men lost to: \{([^}]*)\}.*/\1/' | grep -o ': [0-9]*' | grep -o '[0-9]*' | paste -sd+ | bc 2>/dev/null)
      mins=$(echo "$r" | sed -E 's/.*\| ([0-9.]+) min.*/\1/')
      [ -n "$lost" ] && res="$res, $lost men lost in $mins min"
    fi
    out="$out [seed $seed: $res]"
  done
  echo "$1 $md:$out"
done
