#!/bin/bash
#
# A download utility to test throughput and duration that leverages configurable, concurrent, multipart downloads.
#
# Uses cURL and bc utilities.

# Function to check if all required arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: foldspace <url> <chunk-size-bytes> <max-parallel-requests>"
    exit 1
fi

URL="$1"
CHUNK_SIZE="$2"
MAX_PARALLEL="$3"

# Intentionally do a GET request instead of a HEAD request to avoid errors when the presigned URL
# is only signed for GET's and not HEAD's. Use a Range header to only request a single byte to
# avoid spending time here, but still get the total response returned.
TOTAL_SIZE=$(curl -H "Range: bytes=0-0" -s -D - "$URL" | grep -i "Content-Range" | awk -F'/' '{print $2}' | tr -d '\r')

if [ -z "$TOTAL_SIZE" ]; then
    echo "Could not determine the file size. Exiting."
    exit 1
fi

# Print total size of the download
echo "Total size of the download: $TOTAL_SIZE bytes"

# Calculate the number of chunks needed
NUM_CHUNKS=$(( (TOTAL_SIZE + CHUNK_SIZE - 1) / CHUNK_SIZE ))

# Function to download a specific chunk
download_chunk() {
    local start_byte=$1
    local end_byte=$2

    curl -s --range "$start_byte-$end_byte" "$URL" -o /dev/null
}

# Start time
start_time=$(date +%s)

# Initialize completed chunks count for progress calculation
completed_chunks=0
total_downloaded=0

# Loop through and download chunks in parallel
for (( i=0; i<NUM_CHUNKS; i++ )); do
    start_byte=$(( i * CHUNK_SIZE ))
    end_byte=$(( start_byte + CHUNK_SIZE - 1 ))

    if [ "$end_byte" -ge "$TOTAL_SIZE" ]; then
        end_byte=$(( TOTAL_SIZE - 1 ))
    fi

    # Run the downloads in parallel, limiting to the specified max
    ((i % MAX_PARALLEL == 0)) && wait

    # Download the chunk and increase the completed count
    download_chunk "$start_byte" "$end_byte" &

    # Track progress
    completed_chunks=$(( completed_chunks + 1 ))
    total_downloaded=$(( total_downloaded + (end_byte - start_byte + 1) ))

    # Calculate progress
    progress=$(( (completed_chunks * 100) / NUM_CHUNKS ))

    # Current time for calculating the elapsed time
    current_time=$(date +%s)
    elapsed_time=$(( current_time - start_time ))

    # Calculate the current throughput (bytes per second)
    if [ "$elapsed_time" -gt 0 ]; then
        current_throughput=$(( total_downloaded / elapsed_time ))
        current_throughput_mbps=$(echo "scale=2; ($current_throughput * 8) / 1000000" | bc)
    else
        current_throughput_mbps=0
    fi

    # Print progress, throughput, and elapsed time
    echo -ne "Progress: $progress% | Throughput: $current_throughput_mbps Mbps | Elapsed time: ${elapsed_time}s\r"
done

wait

# End time
end_time=$(date +%s)

# Calculate final duration and throughput
duration=$(( end_time - start_time ))

if [ "$duration" -eq 0 ]; then
    echo "Download completed too quickly to measure throughput."
    exit 0
fi

# Calculate average throughput in bytes per second
average_throughput=$(echo "$TOTAL_SIZE / $duration" | bc)
average_throughput_mbps=$(echo "scale=2; ($average_throughput * 8) / 1000000" | bc)

# Ensure the final output of progress is 100%
echo -ne "Progress: 100% | Throughput: $average_throughput_mbps Mbps | Elapsed time: ${duration}s\n"

echo "Download completed in $duration seconds"
echo "Average throughput: $average_throughput_mbps Mbps"
