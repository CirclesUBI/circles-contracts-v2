from decimal import Decimal, getcontext

# Set the precision to 60 decimals
getcontext().prec = 60

# Define the constant gamma as a Decimal with 60 decimals of precision
gamma = Decimal('0.9998013320085989574306134065681911664857225676913333806934')

# print new header for table multiplying everything by 24
print("\n\n Reproduce table T`(n) counting full 24 CRC/day \n\n")

# Header for the table
print(f"{'n':<5}{'T`(n) (up to 25 decimals)':<40}{'64x64 Fixed Int (rounded)':<30}")

# Separator for the table
print('-' * 75)

# Initialize an empty list to store the 64x64 fixed results
T_fixed_results = []

# For n = 0 the first term is not present in the formula
result = Decimal('24');
fixed_result = result * (Decimal(2)**Decimal(64))
rounded_fixed_result = round(fixed_result)
T_fixed_results.append(rounded_fixed_result)
# Format the result to display up to 25 decimal places
formatted_result = f"{result:.25f}"
print(f"{0:<5}{formatted_result:<40}{str(rounded_fixed_result):<30}")

# Compute the formula for n = 1 to 14 with high precision and print results in a table
for n in range(1, 15):
    gamma_n = gamma**Decimal(n)
    numerator = gamma_n - Decimal('1')
    denominator = gamma - Decimal('1')
    result = Decimal('24')* (numerator / denominator + gamma_n)
    fixed_result = result * (Decimal(2)**Decimal(64))
    rounded_fixed_result = round(fixed_result)
    # Add the rounded fixed result to the list
    T_fixed_results.append(rounded_fixed_result)
    # Format the result to display up to 25 decimal places
    formatted_result = f"{result:.25f}"
    print(f"{n:<5}{formatted_result:<40}{str(rounded_fixed_result):<30}")

# print new header for table R(n) for calculating offset in day A
print("\n\n Reproduce table R(n) for offset in day A\n\n")

# Header for the table
print(f"{'n':<5}{'GAMMA^n':<40}{'64x64 Fixed (20 or 21 digits)':<30}")

# Separator for the table
print('-' * 75)

# Initialize an empty list to store the 64x64 fixed results
R_fixed_results = []

# Compute GAMMA^n and its 64x64 fixed representation for n = 1 to 15 with high precision and print results in a table
for n in range(0, 15):
    result = gamma**Decimal(n)
    fixed_result = result * (Decimal(2)**Decimal(64))
    rounded_fixed_result = round(fixed_result)
    # Add the rounded fixed result to the list
    R_fixed_results.append(rounded_fixed_result)
    # Format the beta^(-n) result to display with precision
    formatted_result = f"{result:.25f}"
    print(f"{n:<5}{formatted_result:<40}{str(rounded_fixed_result):<30}")


# print a message for solidity syntax
print("\n\n Solidity syntax for T` and R arrays\n\n")

# Output the stored 64x64 fixed values in Solidity constant length array syntax
T_solidity_array_syntax = "int128[15] public T = [" + ", ".join(f"int128({value})" for value in T_fixed_results) + "];\n\n"
R_solidity_array_syntax = "int128[15] public R = [" + ", ".join(f"int128({value})" for value in R_fixed_results) + "];\n\n"
print(T_solidity_array_syntax)
print(R_solidity_array_syntax)