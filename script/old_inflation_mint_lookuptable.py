from decimal import Decimal, getcontext

# Set the precision to 60 decimals
getcontext().prec = 60

# Define the constant beta as a Decimal with 60 decimals of precision
beta = Decimal('1.0001987074682146291562714890133039617432343970799554367508')  # Adjust this value to your specific beta with 25 decimal precision, if different

# print new header for table multiplying everything by 24
print("\n\n Reproduce table T(n) counting full 24 CRC/day \n\n")

# Header for the table
print(f"{'n':<5}{'T(n) (up to 25 decimals)':<40}{'64x64 Fixed Int (rounded)':<30}")

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
    numerator = beta**Decimal(n) - Decimal('1')
    denominator = beta**(Decimal(n)+1) - beta**Decimal(n)
    result = Decimal('24')* (numerator / denominator + Decimal('1'))
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
print(f"{'n':<5}{'Beta^(-n)':<40}{'64x64 Fixed (20 or 21 digits)':<30}")

# Separator for the table
print('-' * 75)

# Initialize an empty list to store the 64x64 fixed results
R_fixed_results = []

# Compute beta^(-n) and its 64x64 fixed representation for n = 1 to 15 with high precision and print results in a table
for n in range(0, 15):
    result = beta**(Decimal('-1') * Decimal(n))
    fixed_result = result * (Decimal(2)**Decimal(64))
    rounded_fixed_result = round(fixed_result)
    # Add the rounded fixed result to the list
    R_fixed_results.append(rounded_fixed_result)
    # Format the beta^(-n) result to display with precision
    formatted_result = f"{result:.25f}"
    print(f"{n:<5}{formatted_result:<40}{str(rounded_fixed_result):<30}")


# print a message for solidity syntax
print("\n\n Solidity syntax for T and R arrays\n\n")

# Output the stored 64x64 fixed values in Solidity constant length array syntax
T_solidity_array_syntax = "int128[15] public T = [" + ", ".join(f"int128({value})" for value in T_fixed_results) + "];\n\n"
R_solidity_array_syntax = "int128[15] public R = [" + ", ".join(f"int128({value})" for value in R_fixed_results) + "];\n\n"
print(T_solidity_array_syntax)
print(R_solidity_array_syntax)