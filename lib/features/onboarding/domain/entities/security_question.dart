enum SecurityQuestion {
  petName(id: 'pet_name', prompt: '¿Cuál era el nombre de tu primera mascota?'),
  childhoodNickname(
    id: 'childhood_nickname',
    prompt: '¿Cuál era el apodo que tenías de pequeño?',
  ),
  firstSchool(
    id: 'first_school',
    prompt: '¿Cuál fue el nombre de tu primera escuela?',
  ),
  motherMiddleName(
    id: 'mother_middle_name',
    prompt: '¿Cuál es el segundo nombre de tu madre?',
  ),
  childhoodFriend(
    id: 'childhood_friend',
    prompt: '¿Cuál era el nombre de tu mejor amigo de la infancia?',
  );

  const SecurityQuestion({required this.id, required this.prompt});

  final String id;
  final String prompt;
}
