import os
import re

func_path = '/Users/robiussani/Documents/online_platform/functions/index.js'
with open(func_path, 'r') as f:
    content = f.read()

# Update the gig document to save both rating and averageRating
content = content.replace('rating: Number(averageRating.toFixed(1)),', 'rating: Number(averageRating.toFixed(1)),\n        averageRating: Number(averageRating.toFixed(1)),')

with open(func_path, 'w') as f:
    f.write(content)

print("Updated index.js")
