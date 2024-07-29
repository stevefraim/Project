import os
import json

# Define the path to the directory containing JSON files and the output file
json_dir = '/home/orcaai-configs/ship/prod/recipes'
output_file = 'ships_with_ingredient.txt'

# Function to search for a specific ingredient in the recipes
def find_ingredient(directory, ingredient):
    ships_with_ingredient = []
    for filename in os.listdir(directory):  # List all files in the directory
            file_path = os.path.join(directory, filename)  # Create the full file path
            with open(file_path, 'r') as file:  # Open the JSON file
                data = json.load(file)  # Parse the JSON content into a Python dictionary
                if 'ingredients' in data:  # Check if 'ingredients' key exists in the data
                    for item in data['ingredients']:  # Loop over each item in the 'ingredients' list
                        if 'path' in item and item['path'].endswith(ingredient):  # Check if the ingredient path ends with the specified ingredient
                            ships_with_ingredient.append(filename)  # Add the filename to the list
                            break  # Stop looping through ingredients for this file
    return ships_with_ingredient

# Function to write the results to a text file
def write_results_to_file(results, output_path):
    with open(output_path, 'w') as file:  # Open the output file in write mode
        for item in results:  # Loop over each result
            file.write(f"{item}\n")  # Write each result to the file
    print(f"Results written to {output_path}")  # Print a success message

# Main function to execute the tasks
if __name__ == '__main__':
    ingredient_to_find = 'new_imu.json'  # The ingredient you want to search for
    ships_with_ingredient = find_ingredient(json_dir, ingredient_to_find)  # Find recipes containing the ingredient
    if ships_with_ingredient:  # Check if any recipes were found
        write_results_to_file(ships_with_ingredient, output_file)  # Write the results to the output file
