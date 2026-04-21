import asyncio
from sqlalchemy import delete, select

from app.db.session import AsyncSessionLocal
from app.models.lesson import Lesson

ALL_LESSONS = [
  {
    "level": "A1",
    "type": "composite",
    "order_index": 1,
    "xp_reward": 10,
    "content": {
      "blocks": [
        {
          "type": "sentence",
          "title": "1. L'Essentiel: Bonjour",
          "hint": "The most important word in France.",
          "base_explanation": "In French culture, 'Bonjour' is not just a greeting; it is a prerequisite for any interaction. Never ask a question without saying it first.",
          "explanation_placement": "top",
          "content": "Bonjour ! Enchanté de vous rencontrer.",
          "has_question": False
        },
        {
          "type": "dialogue",
          "title": "2. L'Échange: Comment ça va ?",
          "hint": "Social reciprocity.",
          "base_explanation": "When someone asks how you are, it is polite to return the question using 'Et vous ?' (formal) or 'Et toi ?' (informal).",
          "dialogue_prompt": "Bonjour ! Comment allez-vous ?",
          "dialogue_choices": ["Je vais bien, merci. Et vous ?", "Oui, c'est ça.", "Je m'appelle Marc."],
          "dialogue_answer": "Je vais bien, merci. Et vous ?",
          "choices": ["Je vais bien, merci. Et vous ?", "Oui, c'est ça.", "Je m'appelle Marc."],
          "answer": "Je vais bien, merci. Et vous ?",
          "dialogue": [
            {"speaker": "Professeur", "text": "Bonjour ! Comment allez-vous ?", "mine": False},
            {"speaker": "Étudiant", "text": "...", "mine": True}
          ],
          "has_question": True
        },
        {
          "type": "ordering",
          "title": "3. Syntaxe: Je m'appelle",
          "hint": "Subject + Reflexive Pronoun + Verb.",
          "base_explanation": "To introduce yourself, French uses the reflexive verb 's'appeler' (to call oneself).",
          "tokens": ["m'appelle", "Hana", "Je", "."],
          "ordering_answer": "Je m'appelle Hana",
          "answer": "Je m'appelle Hana",
          "has_question": True
        },
        {
          "type": "translation_mcq",
          "title": "4. Vocabulaire: Les Titres",
          "hint": "Respect and Protocol.",
          "base_explanation": "Use 'Monsieur' for a man and 'Madame' for a woman.",
          "mcq_title": "Comment dit-on 'Good morning, Sir' ?",
          "mcq_choices": ["Bonjour, Monsieur", "Bonjour, Madame", "Salut, Monsieur"],
          "mcq_answer": "Bonjour, Monsieur",
          "choices": ["Bonjour, Monsieur", "Bonjour, Madame", "Salut, Monsieur"],
          "answer": "Bonjour, Monsieur",
          "has_question": True
        },
        {
          "type": "cloze",
          "title": "5. Grammaire: Le Verbe Être",
          "hint": "The verb 'to be'.",
          "base_explanation": "The verb 'être' is the foundation of identity. 'Je suis' means 'I am'.",
          "text": "Bonjour, je [____] étudiant.",
          "choices": ["suis", "es", "est"],
          "answer": "suis",
          "has_question": True
        },
        {
          "type": "matching",
          "title": "6. Registre: Formel vs Informel",
          "hint": "Match the greeting to the situation.",
          "base_explanation": "Distinguishing between formal and informal is vital in French.",
          "pairs": [
            {"key": "Salut !", "value": "Informal (Friends)"},
            {"key": "Bonjour, Monsieur", "value": "Formal (Business)"},
            {"key": "Bonsoir", "value": "Evening Greeting"}
          ],
          "choices": ["Informal (Friends)", "Formal (Business)", "Evening Greeting"],
          "answer": "Formal (Business)",
          "has_question": True
        },
        {
          "type": "phonetic_analysis",
          "title": "7. Phonétique: Le 'H' Muet",
          "hint": "Silent letters.",
          "base_explanation": "In French, the letter 'H' is almost always silent. In 'Hana', the 'H' is not pronounced.",
          "prompt": "How is the 'H' in 'Hana' pronounced in French?",
          "choices": ["Strong breath (Hhh)", "It is silent (Ana)", "Like a 'K' sound"],
          "answer": "It is silent (Ana)",
          "has_question": True
        },
        {
          "type": "cultural_insight",
          "title": "8. Culture: Le Contact Visuel",
          "hint": "Non-verbal communication.",
          "base_explanation": "In France, maintaining eye contact during a greeting is a sign of honesty.",
          "prompt": "When saying 'Enchanté', you should:",
          "choices": ["Look at the person's eyes", "Look at the ground", "Look away"],
          "answer": "Look at the person's eyes",
          "has_question": True
        },
        {
          "type": "transformation",
          "title": "9. Révision: La Politesse",
          "hint": "Friendly to Formal.",
          "base_explanation": "Turning a casual 'Salut' into a polite greeting for a professional setting.",
          "prompt": "Transformez 'Salut' en bonjour formel pour un homme.",
          "answer": "Bonjour Monsieur",
          "choices": ["Bonjour Monsieur", "Salut Monsieur", "Bonsoir Monsieur"],
          "has_question": True
        },
        {
          "type": "logic_analysis",
          "title": "10. Synthèse: Choisir le bon mot",
          "hint": "Time of day context.",
          "base_explanation": "French greetings change by the sun. Use 'Bonjour' in the morning and 'Bonsoir' after dusk.",
          "prompt": "Il est 20h00 (8 PM). Que dites-vous ?",
          "choices": ["Bonjour", "Bonsoir", "Enchanté"],
          "answer": "Bonsoir",
          "has_question": True
        }
      ]
    }
  },
  {
    "level": "A1",
    "type": "composite",
    "order_index": 2,
    "xp_reward": 10,
    "content": {
      "blocks": [
        {
          "type": "sentence",
          "title": "1. Le Concept: Posséder son âge",
          "hint": "In French, you 'have' years.",
          "base_explanation": "In French, you use 'Avoir' (to have) for age, not 'être' (to be).",
          "content": "J'ai vingt-cinq ans.",
          "has_question": False
        },
        {
          "type": "dialogue",
          "title": "2. L'Information: Le Numéro de Téléphone",
          "hint": "Numbers are grouped by two.",
          "dialogue_prompt": "Quel est votre numéro de téléphone ?",
          "dialogue_choices": ["C'est le 06 12 34 56 78.", "Je suis le 06 12.", "J'appelle demain."],
          "dialogue_answer": "C'est le 06 12 34 56 78.",
          "choices": ["C'est le 06 12 34 56 78.", "Je suis le 06 12.", "J'appelle demain."],
          "answer": "C'est le 06 12 34 56 78.",
          "dialogue": [
            {"speaker": "Secrétaire", "text": "Quel est votre numéro de téléphone ?", "mine": False},
            {"speaker": "Client", "text": "...", "mine": True}
          ],
          "has_question": True
        },
        {
          "type": "ordering",
          "title": "3. Syntaxe: Demander l'âge",
          "hint": "Question word + Verb + Subject.",
          "tokens": ["âge", "avez", "Quel", "vous", "?"],
          "ordering_answer": "Quel âge avez vous ?",
          "answer": "Quel âge avez vous ?",
          "has_question": True
        },
        {
          "type": "translation_mcq",
          "title": "4. Vocabulaire: Les Chiffres Clés",
          "hint": "12 vs 20.",
          "mcq_title": "Comment dit-on le chiffre '12' ?",
          "mcq_choices": ["Douze", "Deux", "Vingt"],
          "mcq_answer": "Douze",
          "choices": ["Douze", "Deux", "Vingt"],
          "answer": "Douze",
          "has_question": True
        },
        {
          "type": "cloze",
          "title": "5. Grammaire: Le Verbe 'Avoir'",
          "hint": "Conjugation for 'Tu'.",
          "text": "Tu [____] dix-huit ans.",
          "choices": ["as", "ai", "a"],
          "answer": "as",
          "has_question": True
        },
        {
          "type": "matching",
          "title": "6. Logique: Chiffres et Lettres",
          "hint": "Match digits to words.",
          "pairs": [
            {"key": "8", "value": "Huit"},
            {"key": "11", "value": "Onze"},
            {"key": "15", "value": "Quinze"}
          ],
          "choices": ["Huit", "Onze", "Quinze"],
          "answer": "Onze",
          "has_question": True
        },
        {
          "type": "mathematical_analysis",
          "title": "7. Analyse: Calcul Mental",
          "hint": "Solve in French.",
          "prompt": "Combien font 'sept' plus 'six' ?",
          "choices": ["Treize (13)", "Quatorze (14)", "Douze (12)"],
          "answer": "Treize (13)",
          "has_question": True
        },
        {
          "type": "transformation",
          "title": "8. Transformation: De l'écrit à l'oral",
          "hint": "Data to sentence.",
          "prompt": "Data: [Nom: Jean | Age: 19]. Create the 'Age' sentence.",
          "answer": "Jean a dix-neuf ans.",
          "choices": ["Jean a dix-neuf ans.", "Jean est dix-neuf.", "Jean a dix-neuf."],
          "has_question": True
        }
      ]
    }
  },
  {
    "level": "A1",
    "type": "composite",
    "order_index": 3,
    "xp_reward": 10,
    "content": {
      "blocks": [
        {
          "type": "sentence",
          "title": "1. Le Concept: L'Adjectif Possessif",
          "hint": "The object's gender matters.",
          "base_explanation": "Use 'Mon' (masc) or 'Ma' (fem) based on the family member's gender.",
          "content": "Voici ma mère et mon père.",
          "has_question": False
        },
        {
          "type": "dialogue",
          "title": "2. L'Enquête: Frères et Sœurs",
          "hint": "Asking about siblings.",
          "dialogue_prompt": "Est-ce que tu as des frères et sœurs ?",
          "dialogue_choices": ["Oui, j'ai un frère et une sœur.", "Je m'appelle Jean.", "Ma mère est française."],
          "dialogue_answer": "Oui, j'ai un frère et une sœur.",
          "choices": ["Oui, j'ai un frère et une sœur.", "Je m'appelle Jean.", "Ma mère est française."],
          "answer": "Oui, j'ai un frère et une sœur.",
          "dialogue": [
            {"speaker": "Ami", "text": "Est-ce que tu as des frères et sœurs ?", "mine": False},
            {"speaker": "Vous", "text": "...", "mine": True}
          ],
          "has_question": True
        },
        {
          "type": "ordering",
          "title": "3. Syntaxe: Présenter ses parents",
          "hint": "Possessive + Noun + Verb + Adjective.",
          "tokens": ["père", "Mon", "est", "professeur", "."],
          "ordering_answer": "Mon père est professeur",
          "answer": "Mon père est professeur",
          "has_question": True
        },
        {
          "type": "translation_mcq",
          "title": "4. Vocabulaire: La Famille",
          "hint": "Son vs Brother.",
          "mcq_title": "Comment dit-on 'The daughter' ?",
          "mcq_choices": ["La fille", "Le fils", "La femme"],
          "mcq_answer": "La fille",
          "choices": ["La fille", "Le fils", "La femme"],
          "answer": "La fille",
          "has_question": True
        },
        {
          "type": "cloze",
          "title": "5. Grammaire: L'accord",
          "hint": "Use 'Ma' for sister.",
          "text": "C'est [____] sœur. Elle s'appelle Sarah.",
          "choices": ["ma", "mon", "mes"],
          "answer": "ma",
          "has_question": True
        },
        {
          "type": "matching",
          "title": "6. Logique: Masculin vs Féminin",
          "hint": "Pair equivalents.",
          "pairs": [
            {"key": "Le père", "value": "La mère"},
            {"key": "Le frère", "value": "La sœur"},
            {"key": "Le grand-père", "value": "La grand-mère"}
          ],
          "choices": ["La mère", "La sœur", "La grand-mère"],
          "answer": "La sœur",
          "has_question": True
        },
        {
          "type": "logic_analysis",
          "title": "7. Analyse: Liens de Parenté",
          "hint": "Family trees.",
          "prompt": "Le père de mon père est mon...",
          "choices": ["Grand-père", "Oncle", "Frère"],
          "answer": "Grand-père",
          "has_question": True
        },
        {
          "type": "transformation",
          "title": "8. Transformation: La Négation",
          "hint": "Use 'ne... pas'.",
          "prompt": "Transform into negative: 'J'ai un frère.'",
          "answer": "Je n'ai pas de frère.",
          "choices": ["Je n'ai pas de frère.", "Je suis pas de frère.", "Je n'ai un frère pas."],
          "has_question": True
        }
      ]
    }
  },
  {
    "level": "A1",
    "type": "composite",
    "order_index": 4,
    "xp_reward": 10,
    "content": {
      "blocks": [
        {
          "type": "sentence",
          "title": "1. Le Concept: Exprimer ses goûts",
          "hint": "Use definite articles.",
          "base_explanation": "In French, use 'le', 'la', or 'les' after verbs of preference.",
          "content": "J'aime le café et j'adore la musique.",
          "has_question": False
        },
        {
          "type": "dialogue",
          "title": "2. L'Échange: Les Hobbies",
          "hint": "What do you like?",
          "dialogue_prompt": "Qu'est-ce que tu aimes faire ?",
          "dialogue_choices": ["J'aime regarder la télévision.", "Je n'ai pas de frère.", "Il est midi."],
          "dialogue_answer": "J'aime regarder la télévision.",
          "choices": ["J'aime regarder la télévision.", "Je n'ai pas de frère.", "Il est midi."],
          "answer": "J'aime regarder la télévision.",
          "dialogue": [
            {"speaker": "Collègue", "text": "Qu'est-ce que tu aimes faire ?", "mine": False},
            {"speaker": "Vous", "text": "...", "mine": True}
          ],
          "has_question": True
        },
        {
          "type": "ordering",
          "title": "3. Syntaxe: L'intensité",
          "hint": "Verb + beaucoup.",
          "tokens": ["beaucoup", "le", "J'aime", "cinéma", "."],
          "ordering_answer": "J'aime beaucoup le cinéma",
          "answer": "J'aime beaucoup le cinéma",
          "has_question": True
        },
        {
          "type": "translation_mcq",
          "title": "4. Vocabulaire: Les Activités",
          "hint": "Common verbs.",
          "mcq_title": "Comment dit-on 'To listen to music' ?",
          "mcq_choices": ["Écouter de la musique", "Regarder la musique", "Lire la musique"],
          "mcq_answer": "Écouter de la musique",
          "choices": ["Écouter de la musique", "Regarder la musique", "Lire la musique"],
          "answer": "Écouter de la musique",
          "has_question": True
        },
        {
          "type": "cloze",
          "title": "5. Grammaire: L'élision",
          "hint": "L' before vowel.",
          "text": "J'aime [____] informatique.",
          "choices": ["l'", "le", "la"],
          "answer": "l'",
          "has_question": True
        },
        {
          "type": "matching",
          "title": "6. Logique: Verbe et Objet",
          "hint": "Match actions.",
          "pairs": [
            {"key": "Lire", "value": "Un livre"},
            {"key": "Regarder", "value": "Un film"},
            {"key": "Jouer", "value": "Au football"}
          ],
          "choices": ["Un livre", "Un film", "Au football"],
          "answer": "Un film",
          "has_question": True
        },
        {
          "type": "logic_analysis",
          "title": "7. Analyse: Sentiment",
          "hint": "Rank feelings.",
          "prompt": "Lequel est le plus fort ?",
          "choices": ["J'adore", "J'aime", "Je n'aime pas"],
          "answer": "J'adore",
          "has_question": True
        },
        {
          "type": "transformation",
          "title": "8. Transformation: Aversion",
          "hint": "Negative likes.",
          "prompt": "Transform into negative: 'J'aime le chocolat.'",
          "answer": "Je n'aime pas le chocolat.",
          "choices": ["Je n'aime pas le chocolat.", "Je n'aime le chocolat.", "Je suis pas le chocolat."],
          "has_question": True
        }
      ]
    }
  },
  {
    "level": "A1",
    "type": "composite",
    "order_index": 5,
    "xp_reward": 10,
    "content": {
      "blocks": [
        {
          "type": "sentence",
          "title": "1. Le Concept: Localisation",
          "hint": "à vs en.",
          "base_explanation": "Cities use 'à', feminine countries use 'en'.",
          "content": "J'habite à Paris, en France.",
          "has_question": False
        },
        {
          "type": "dialogue",
          "title": "2. L'Enquête: Logement",
          "hint": "Where?",
          "dialogue_prompt": "Où habitez-vous ?",
          "dialogue_choices": ["J'habite à Lyon.", "Je suis professeur.", "J'aime ma mère."],
          "dialogue_answer": "J'habite à Lyon.",
          "choices": ["J'habite à Lyon.", "Je suis professeur.", "J'aime ma mère."],
          "answer": "J'habite à Lyon.",
          "dialogue": [
            {"speaker": "Agent", "text": "Où habitez-vous ?", "mine": False},
            {"speaker": "Client", "text": "...", "mine": True}
          ],
          "has_question": True
        },
        {
          "type": "ordering",
          "title": "3. Syntaxe: Logement",
          "hint": "Subject + Verb + Article.",
          "tokens": ["habite", "une", "maison", "Je", "dans", "."],
          "ordering_answer": "Je habite dans une maison",
          "answer": "Je habite dans une maison",
          "has_question": True
        },
        {
          "type": "translation_mcq",
          "title": "4. Vocabulaire: Habitation",
          "hint": "House types.",
          "mcq_title": "Comment dit-on 'A house with a garden' ?",
          "mcq_choices": ["Une maison avec un jardin", "Un appartement", "Un studio"],
          "mcq_answer": "Une maison avec un jardin",
          "choices": ["Une maison avec un jardin", "Un appartement", "Un studio"],
          "answer": "Une maison avec un jardin",
          "has_question": True
        },
        {
          "type": "cloze",
          "title": "5. Grammaire: Préposition",
          "hint": "Cities use 'à'.",
          "text": "Il habite [____] Paris.",
          "choices": ["à", "en", "au"],
          "answer": "à",
          "has_question": True
        },
        {
          "type": "matching",
          "title": "6. Logique: Pièces",
          "hint": "Match rooms.",
          "pairs": [
            {"key": "La cuisine", "value": "Préparer le repas"},
            {"key": "La chambre", "value": "Dormir"},
            {"key": "Le salon", "value": "Regarder la télé"}
          ],
          "choices": ["Préparer le repas", "Dormir", "Regarder la télé"],
          "answer": "Dormir",
          "has_question": True
        },
        {
          "type": "logic_analysis",
          "title": "7. Analyse: Ville",
          "hint": "Distinguish category.",
          "prompt": "Lequel est une VILLE ?",
          "choices": ["Marseille", "Italie", "Afrique"],
          "answer": "Marseille",
          "has_question": True
        },
        {
          "type": "transformation",
          "title": "8. Transformation: Pluriel",
          "hint": "Change to 'Nous'.",
          "prompt": "Transformez: 'J'habite à Paris' → 'Nous...'",
          "answer": "Nous habitons à Paris.",
          "choices": ["Nous habitons à Paris.", "Nous habite à Paris.", "Nous sommes à habiter Paris."],
          "has_question": True
        }
      ]
    }
  }
]

async def seed() -> None:
    async with AsyncSessionLocal() as session:
        await session.execute(delete(Lesson))
        await session.commit()

        session.add_all([Lesson(**item) for item in ALL_LESSONS])
        await session.commit()

        result = await session.execute(select(Lesson))
        count = len(result.scalars().all())
        print(f"Seeded {count} lessons")


if __name__ == "__main__":
    asyncio.run(seed())