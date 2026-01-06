Product Overview

Goal: Help a user quickly estimate carbs in a meal using AI on three photos.

Core user flow
Home screen with big Take picture button.
Photo-Screen #1 opens the camera with the instruction “Scan from above”. Capture first photo.
Photo-Screen #2 opens immediately with the instruction “Scan 45 degree”. Capture second photo.
Photo-Screen #3 opens immediately with the instruction “Scan 90 degree”. Capture third photo.
- The three photo screens should not just be default iOS camera recordings, but they should be views that have a camera preview and a capture button created using swift UI. 
The photos are saved intermediately - transitions between PhotoView's should be smooth

Go to ResultView
Send the three images along with this prompt to Google AI:
"Analyze the three images showing different perspectives of the same meal.
                Accurately identify each component of the meal.
                Use the visible reference item to precisely determine volumes, then convert to weight using appropriate food densities.
                Use net carbohydrate percentage to calculate the net carb content for each component and for the entire meal.

                Return ONLY valid JSON (no markdown fences, no extra commentary). Use this exact schema and key names:
                {
                  \"components\": [
                    {
                      \"description\": string,
                      \"estimatedWeightGrams\": number,   // grams
                      \"carbPercentage\": number,         // percentage as whole number (e.g., 23)
                      \"carbContentGrams\": number        // grams
                    }
                  ],
                  \"totalCarbGrams\": number,            // sum of all components' carbContentGrams
                  \"confidence\": integer,               // 1-9
                  \"mealSummary\": string                // one-line description
                }

                Rules:
                - Use grams for weights and net carbohydrate content. Prefer integers where reasonable.
                - Express carbPercentage as a whole number (e.g., 23 for 23%).
                - Ensure the JSON is syntactically valid and parseable by JSONDecoder.
                - Do not include any text before or after the JSON.
                - Assume the three images depict the same meal from different angles and use the reference item consistently across images.
                - Use the weight of edible parts of food components and also name them that way e.g. Mango (edible part)"
                
                
This data will be presented in ResultView. ResultView is already created and the design is perfect like this. 




