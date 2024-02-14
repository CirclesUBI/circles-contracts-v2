from decimal import Decimal, getcontext

# Set the precision to 60 decimals
getcontext().prec = 60

# Define the constant beta as a Decimal with 60 decimals of precision
beta = Decimal('1.0001987074682146291562714890133039617432343970799554367508')  # Adjust this value to your specific beta with 25 decimal precision, if different

# Header for the table
print(f"{'n':<5}{'Result (up to 25 decimals)':<40}{'64x64 Fixed Int (rounded)':<30}")

# Separator for the table
print('-' * 75)

# For n = 0 the first term is not present in the formula
result = Decimal('1');
fixed_result = result * (Decimal(2)**Decimal(64))
rounded_fixed_result = round(fixed_result)
# Format the result to display up to 25 decimal places
formatted_result = f"{result:.25f}"
print(f"{0:<5}{formatted_result:<40}{str(rounded_fixed_result):<30}")

# Compute the formula for n = 1 to 14 with high precision and print results in a table
for n in range(1, 15):
    numerator = beta**Decimal(n) - Decimal('1')
    denominator = beta**(Decimal(n)+1) - beta**Decimal(n)
    result = numerator / denominator + Decimal('1')
    fixed_result = result * (Decimal(2)**Decimal(64))
    rounded_fixed_result = round(fixed_result)
    # Format the result to display up to 25 decimal places
    formatted_result = f"{result:.25f}"
    print(f"{n:<5}{formatted_result:<40}{str(rounded_fixed_result):<30}")

# print new header for second table multiplying everything by 24
print("\n\n Reproduce table but multiply by 24 CRC/day \n\n")

# Header for the table
print(f"{'n':<5}{'Result (up to 25 decimals)':<40}{'64x64 Fixed Int (rounded)':<30}")

# Separator for the table
print('-' * 75)

# For n = 0 the first term is not present in the formula
result = Decimal('24');
fixed_result = result * (Decimal(2)**Decimal(64))
rounded_fixed_result = round(fixed_result)
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
    # Format the result to display up to 25 decimal places
    formatted_result = f"{result:.25f}"
    print(f"{n:<5}{formatted_result:<40}{str(rounded_fixed_result):<30}")