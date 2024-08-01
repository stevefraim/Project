import os
import json
import subprocess

# Define the path to the directory containing JSON files and the output files
json_dir = os.path.expanduser('~/orcaai-configs/ship/prod/recipes')
output_file_with_new_imu = 'ships_with_new_imu.txt'
output_file_missing_orca_imu_port = 'ships_missing_orca_imu_port.txt'

# Pull the latest changes from the Git repository
def git_pull():
    try:
        subprocess.run(['git', 'pull'], check=True, cwd=json_dir)  # Run the git pull command in the specified directory
        print('Git pull successful.')  # Print a success message
    except subprocess.CalledProcessError as e:  # Handle any errors that occur during the git pull
        print(f'Git pull failed: {e}')  # Print an error message if the git pull fails

# Function to find recipes with the specified ingredient
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

# Function to check for another ingredient and identify missing ones
def find_recipes_without_orca_imu_port(directory, recipes, orca_imu_port_ingredient):
    recipes_without_orca_imu_port = []
    for filename in recipes:  # Iterate over the list of recipes with new_imu.json
        file_path = os.path.join(directory, filename)  # Create the full file path
        with open(file_path, 'r') as file:  # Open the file in read mode
            data = json.load(file)  # Load the JSON data from the file
            # Check if the ingredient 'orca_imu_port.json' is in the recipe
            ingredient_found = any(item['path'].endswith(orca_imu_port_ingredient) for item in data['ingredients'])
            if not ingredient_found:  # If the ingredient is not found
                recipes_without_orca_imu_port.append(filename)  # Add the filename to the list
    return recipes_without_orca_imu_port

# Function to write the results to a text file
def write_results_to_file(results, output_path):
    with open(output_path, 'w') as file:  # Open the output file in write mode
        for item in results:  # Loop over each result
            file.write(f"{item}\n")  # Write each result to the file
    print(f"Results written to {output_path}")  # Print a success message

# Main function to execute the tasks
if __name__ == '__main__':
    new_imu_ingredient = 'new_imu.json'  
    orca_imu_port_ingredient = 'orca_imu_port.json'  
    
    # Pull the latest changes from the Git repository
    git_pull()  
    
    # Find recipes with the new IMU ingredient
    ships_with_new_imu = find_recipes_with_new_imu(json_dir, new_imu_ingredient)  # Find recipes containing the new IMU ingredient
    
    # Write the list of recipes with the new IMU to a file
    if ships_with_new_imu:
        write_results_to_file(ships_with_new_imu, output_file_with_new_imu)  # Write the results to the output file
    
    # Find recipes missing the orca IMU port ingredient
    recipes_missing_orca_imu_port = find_recipes_without_orca_imu_port(json_dir, ships_with_new_imu, orca_imu_port_ingredient)  # Find recipes missing the orca IMU port ingredient
    
    # Write the list of recipes missing the orca IMU port to a file
    if recipes_missing_orca_imu_port:
        write_results_to_file(recipes_missing_orca_imu_port, output_file_missing_orca_imu_port)  # Write the results to the output file
    else:
        print('All recipes with new IMU also contain orca IMU port.')  # Print a message if all recipes already contain the orca IMU port ingredient
