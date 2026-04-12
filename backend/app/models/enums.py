
import enum

class RoleEnum(str, enum.Enum):
    """Rôles utilisateur"""
    TECHNICIEN = "TECHNICIEN"
    CHEF_EQUIPE = "CHEF_EQUIPE"
    SUPERVISEUR = "SUPERVISEUR"
    MAGASINIER = "magasinier"
    ADMINISTRATEUR = "ADMINISTRATEUR"


class StatutTechnicienEnum(str, enum.Enum):
    """Statut du technicien"""
    DISPONIBLE = "disponible"
    EN_INTERVENTION = "en_intervention"
    INDISPONIBLE = "indisponible"

    @classmethod
    def _missing_(cls, value):
        if isinstance(value, str):
            for member in cls:
                if member.name.upper() == value.upper() or member.value.upper() == value.upper():
                    return member
        return None


class NiveauExpertiseEnum(str, enum.Enum):
    """Niveau d'expertise"""
    DEBUTANT = "DEBUTANT"
    INTERMEDIAIRE = "INTERMEDIAIRE"
    AVANCE = "AVANCE"
    EXPERT = "EXPERT"


class StatutPanneEnum(str, enum.Enum):
    """Statut d'une panne"""
    EN_ATTENTE = "EN_ATTENTE"
    EN_COURS = "EN_COURS"
    A_VALIDER = "A_VALIDER"
    RESOLUE = "RESOLUE"
    ANNULEE = "ANNULEE"


class GraviteEnum(str, enum.Enum):
    """Gravité d'une panne"""
    FAIBLE = "faible"
    MOYENNE = "moyenne"
    HAUTE = "haute"
    CRITIQUE = "critique"

    @classmethod
    def _missing_(cls, value):
        if isinstance(value, str):
            for member in cls:
                if member.name.upper() == value.upper() or member.value.upper() == value.upper():
                    return member
        return None


class TypeAffectationEnum(str, enum.Enum):
    """Type d'affectation"""
    AUTOMATIQUE = "AUTOMATIQUE"
    MANUELLE = "MANUELLE"
    URGENTE = "URGENTE"
    RENFORT = "RENFORT"


class StatutAutorisationEnum(str, enum.Enum):
    """Statut autorisation"""
    EN_ATTENTE = "EN_ATTENTE"
    APPROUVEE = "APPROUVEE"
    REFUSEE = "REFUSEE"

class StatutInterventionEnum(str, enum.Enum):
    """Statut de l'intervention"""
    EN_ATTENTE = "EN_ATTENTE"
    ACCEPTEE = "ACCEPTEE"
    EN_COURS = "EN_COURS"
    TERMINEE = "TERMINEE"
    ANNULEE = "ANNULEE"

class StatutPresenceEnum(str, enum.Enum):
    """Statut de présence/travail"""
    EN_TRAVAIL = "en_travail"
    HORS_TRAVAIL = "hors_travail"
