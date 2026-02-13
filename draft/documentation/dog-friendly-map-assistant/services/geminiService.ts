import { GoogleGenAI } from "@google/genai";
import { LatLng, AiResponse } from '../types';

export const askGeminiAboutPlaces = async (query: string, location: LatLng | null): Promise<AiResponse> => {
  if (!process.env.API_KEY) {
    throw new Error("API_KEY environment variable not set");
  }

  const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });

  const systemInstruction = `You are an expert assistant for a "Dog Friendly Map" app. Your goal is to help users find dog-friendly places.
- Keep your initial response very brief (1-2 sentences).
- Immediately follow up with a bulleted list of suggested places.
- For each place, provide its name and a very short reason why it's a good match.
- You MUST use the googleMaps tool to provide clickable links for every single suggestion. Your response is not useful without these links.
- Be friendly and concise.`;

  const userContext = location
    ? `The user is currently located at latitude ${location.lat} and longitude ${location.lng}.`
    : 'The user has not provided their location.';

  try {
    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: `${userContext}\n\nUser query: "${query}"`,
      config: {
        tools: [{ googleMaps: {} }],
        systemInstruction,
      },
      toolConfig: location ? {
        retrievalConfig: {
          latLng: {
            latitude: location.lat,
            longitude: location.lng
          }
        }
      } : undefined,
    });

    const text = response.text;
    const groundingChunks = response.candidates?.[0]?.groundMetadata?.groundingChunks || [];

    return {
      text: text,
      sources: groundingChunks.filter((chunk: any) => chunk.maps)
    };
  } catch (error) {
    console.error("Error calling Gemini API:", error);
    return {
      text: "Sorry, I encountered an error while searching. Please check your connection or try again later.",
      sources: []
    };
  }
};
