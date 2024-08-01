import os  
import json  

# Define the path to the directory containing JSON files and the output files
json_dir = os.path.expanduser('~/orcaai-configs/ship/prod/recipes')  # Expand the user path to the full path
output_file_with_new_imu = 'ships_with_new_imu.txt'  
output_file_missing_orca_imu_port = 'ships_missing_orca_imu_port.txt'  

# Function to find recipes with the specified ingredient
def find_recipes_with_new_imu(directory, ingredient):
    recipes_with_new_imu = []  # List to store recipes with the specified ingredient
    for filename in os.listdir(directory):  # List all files in the directory
        file_path = os.path.join(directory, filename)  # Create the full file path
        with open(file_path, 'r') as file:  # Open the file in read mode
            data = json.load(file)  # Load the JSON data from the file
            for item in data['ingredients']:  # Iterate over each ingredient in the recipe
                if item['path'].endswith(ingredient):  # Check if the ingredient path ends with the specified ingredient
                    recipes_with_new_imu.append(filename)  # Add the filename to the list if it matches
                    break  # Exit the loop as we found the ingredient
    return recipes_with_new_imu  # Return the list of recipes with the specified ingredient

# Function to check for another ingredient and identify missing ones
def find_recipes_without_orca_imu_port(directory, recipes, orca_imu_port_ingredient):
    recipes_without_orca_imu_port = []  # List to store recipes missing the specified ingredient
    for filename in recipes:  # Iterate over the list of recipes with new_imu.json
        file_path = os.path.join(directory, filename)  # Create the full file path
        with open(file_path, 'r') as file:  # Open the file in read mode
            data = json.load(file)  # Load the JSON data from the file
            # Check if any ingredient path ends with the specified ingredient
            ingredient_found = any(item['path'].endswith(orca_imu_port_ingredient) for item in data['ingredients'])
            if not ingredient_found:  # If the ingredient is not found
                recipes_without_orca_imu_port.append(filename)  # Add the filename to the list
    return recipes_without_orca_imu_port  # Return the list of recipes missing the specified ingredient

# Function to write the results to a text file
def write_results_to_file(results, output_path):
    with open(output_path, 'w') as file:  # Open the output file in write mode
        for item in results:  # Iterate over the results
            file.write(f"{item}\n")  # Write each item to the file followed by a newline
    print(f"Results written to {output_path}")  # Print a message indicating the results were written

# Main function to execute the tasks
if __name__ == '__main__':
    new_imu_ingredient = 'new_imu.json'  # Define the ingredient to search for
    orca_imu_port_ingredient = 'orca_imu_port.json'  # Define the second ingredient to check for
    
    # Find recipes with the new IMU ingredient
    recipes_with_new_imu = find_recipes_with_new_imu(json_dir, new_imu_ingredient)
    
    # Write the list of recipes with the new IMU to a file
    if recipes_with_new_imu:  # Check if any recipes were found
        write_results_to_file(recipes_with_new_imu, output_file_with_new_imu)
    
    # Find recipes missing the orca IMU port ingredient
    recipes_missing_orca_imu_port = find_recipes_without_orca_imu_port(json_dir, recipes_with_new_imu, orca_imu_port_ingredient)
    
    # Write the list of recipes missing the orca IMU port to a file
    if recipes_missing_orca_imu_port:  # Check if any recipes were found
        write_results_to_file(recipes_missing_orca_imu_port, output_file_missing_orca_imu_port)
    else:
        print('All recipes with new IMU also contain orca IMU port.')  # Print a message if all recipes contain the ingredient
