"""
Imports centralisés de tous les modèles
"""
from app.core.database import Base

# Importer tous les enums
from app.models.enums import *

# Importer les modèles utilisateurs
from app.models.users import *

# Importer les compétences
from app.models.competence import *

# Importer les machines
from app.models.machine import *

# Importer les pannes
from app.models.panne import *

# Importer les interventions
from app.models.intervention import *

# Importer les autorisations
from app.models.autorisation import *

# Importer le magasin (pièces de rechange)
from app.models.magasin import *

# Importer le chat
from app.models.chat import *