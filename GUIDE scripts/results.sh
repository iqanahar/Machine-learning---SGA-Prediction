nano results.sh

#!/bin/bash

# Navigate to your folder (Handling the spaces correctly)
cd "/mnt/c/Users/HP/OneDrive/Desktop/P2 DECISION TREE"

output_file="results.txt"

# 1. Create the .txt file and print the top headers
echo "------------------------------------------------------------------------------------------------" > "$output_file"
printf "%-8s | %-31s | %s\n" "Dataset" "Root Node Variable(s)" "All Variables Used" >> "$output_file"
echo "------------------------------------------------------------------------------------------------" >> "$output_file"

for i in {1..30}; do
    # Skip if the file doesn't exist
    if [ ! -f "data$i.out" ]; then continue; fi

    # 2. Isolate ONLY the branch lines (Node X:)
    tree_lines=$(grep -E "^ *Node [0-9]+:" "data$i.out")
    
    # Grab the first line for the root node
    node_1_line=$(echo "$tree_lines" | head -n 1)

    # 3. Extract exact variables by name (this ignores all numbers and symbols)
    # The list below matches your dataset columns
    var_list="BPD|HC|AC|FL|Nuchal\.fold\.thickness|age|GA_scan"
    
    root_vars=$(echo "$node_1_line" | grep -oE "$var_list" | sort -u | tr '\n' ',' | sed 's/,$//')
    all_vars=$(echo "$tree_lines" | grep -oE "$var_list" | sort -u | tr '\n' ',' | sed 's/,$//')

    # 4. Handle cases where the tree didn't split (No pattern found)
    if [ -z "$all_vars" ]; then
        root_vars="No Splits"
        all_vars="None"
    fi

    # 5. Print the row
    printf "%-8s | %-31s | %s\n" "$i" "$root_vars" "$all_vars" >> "$output_file"
done

echo "------------------------------------------------------------------------------------------------" >> "$output_file"

echo " DONE! Open results.txt to see your summary."
