from setuptools import setup, find_packages

setup(
    name="phonenumber-ae",
    version="0.1.0",
    description="Validate and format international phone numbers, over the "
                "shared pure-Aether libphonenumber engine.",
    packages=find_packages(),
    package_data={"phonenumber_ae": ["native/*"]},
    python_requires=">=3.7",
    license="Apache-2.0",
)
