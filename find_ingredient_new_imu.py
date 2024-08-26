import os
import json

# Define the path to the directory containing JSON files and the output file
json_dir = os.path.expanduser('~/orcaai-configs/ship/prod/recipes')
output_file = 'ships_with_new_imu.txt'

# Function to search for a specific ingredient in the recipes
def find_recipes_with_new_imu(directory, ingredient):
    ships_with_new_imu = []
    for filename in os.listdir(directory):  # List all files in the directory
        file_path = os.path.join(directory, filename)  # Create the full file path
        with open(file_path, 'r') as file:  # Open the JSON file
            data = json.load(file)  # Parse the JSON content into a Python dictionary
            for item in data['ingredients']:  # Directly iterate over ingredients
                if item['path'].endswith(ingredient):  # Check if the ingredient path ends with the specified ingredient
                    ships_with_new_imu.append(filename)  # Add the filename to the list
                    break  # Stop looping through ingredients for this file
    return ships_with_new_imu

# Function to write the results to a text file
def write_results_to_file(results, output_path):
    with open(output_path, 'w') as file:  # Open the output file in write mode
        for item in results:  # Loop over each result
            file.write(f"{item}\n")  # Write each result to the file
    print(f"Results written to {output_path}")  # Print a success message

# Main function to execute the tasks
if __name__ == '__main__':
    new_imu_ingredient = 'new_imu.json'  # The ingredient you want to search for
    ships_with_new_imu = find_recipes_with_new_imu(json_dir, new_imu_ingredient)  # Find recipes containing the ingredient
    if ships_with_new_imu:  # Check if any recipes were found
        write_results_to_file(ships_with_new_imu, output_file)  # Write the results to the output file
